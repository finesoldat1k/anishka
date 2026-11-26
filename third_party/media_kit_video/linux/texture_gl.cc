// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/texture_gl.h"

#include <epoxy/gl.h>
#include <epoxy/egl.h>

struct _TextureGL {
  FlTextureGL parent_instance;
  guint32 name;  // Texture sampled by Flutter (shared with its context).
  guint32 fbo;   // FBO owned by mpv's shared context.
  guint32 current_width;
  guint32 current_height;
  VideoOutput* video_output;
};

G_DEFINE_TYPE(TextureGL, texture_gl, fl_texture_gl_get_type())

static void texture_gl_init(TextureGL* self) {
  self->name = 0;
  self->fbo = 0;
  self->current_width = 1;
  self->current_height = 1;
  self->video_output = NULL;
}

static void texture_gl_dispose(GObject* object) {
  TextureGL* self = TEXTURE_GL(object);
  VideoOutput* video_output = self->video_output;

  if (video_output != NULL) {
    EGLDisplay egl_display = video_output_get_egl_display(video_output);
    EGLContext egl_context = video_output_get_egl_context(video_output);

    if (egl_display != EGL_NO_DISPLAY && egl_context != EGL_NO_CONTEXT) {
      EGLDisplay current_display = eglGetCurrentDisplay();
      EGLContext current_context = eglGetCurrentContext();
      EGLSurface current_draw = eglGetCurrentSurface(EGL_DRAW);
      EGLSurface current_read = eglGetCurrentSurface(EGL_READ);

      if (eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                         egl_context)) {
        if (self->name != 0) {
          glDeleteTextures(1, &self->name);
          self->name = 0;
        }
        if (self->fbo != 0) {
          glDeleteFramebuffers(1, &self->fbo);
          self->fbo = 0;
        }
        if (current_context != EGL_NO_CONTEXT) {
          eglMakeCurrent(current_display, current_draw, current_read,
                         current_context);
        } else {
          eglMakeCurrent(EGL_NO_DISPLAY, EGL_NO_SURFACE, EGL_NO_SURFACE,
                         EGL_NO_CONTEXT);
        }
      }
    }
  }

  self->current_width = 1;
  self->current_height = 1;
  self->video_output = NULL;
  G_OBJECT_CLASS(texture_gl_parent_class)->dispose(object);
}

static void texture_gl_class_init(TextureGLClass* klass) {
  FL_TEXTURE_GL_CLASS(klass)->populate = texture_gl_populate_texture;
  G_OBJECT_CLASS(klass)->dispose = texture_gl_dispose;
}

TextureGL* texture_gl_new(VideoOutput* video_output) {
  TextureGL* self = TEXTURE_GL(g_object_new(texture_gl_get_type(), NULL));
  self->video_output = video_output;
  return self;
}

gboolean texture_gl_populate_texture(FlTextureGL* texture,
                                     guint32* target,
                                     guint32* name,
                                     guint32* width,
                                     guint32* height,
                                     GError** error) {
  TextureGL* self = TEXTURE_GL(texture);
  VideoOutput* video_output = self->video_output;
  if (video_output == NULL) {
    return FALSE;
  }

  // Creates a shared EGL context and mpv's render context on the raster
  // thread, where Flutter's OpenGL context is current.
  if (!video_output_ensure_render_context(video_output)) {
    return FALSE;
  }

  EGLDisplay egl_display = video_output_get_egl_display(video_output);
  EGLContext egl_context = video_output_get_egl_context(video_output);

  EGLDisplay flutter_display = eglGetCurrentDisplay();
  EGLContext flutter_context = eglGetCurrentContext();
  EGLSurface flutter_draw = eglGetCurrentSurface(EGL_DRAW);
  EGLSurface flutter_read = eglGetCurrentSurface(EGL_READ);

  if (!eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                      egl_context)) {
    g_printerr("media_kit: TextureGL: Failed to make EGL context current.\n");
    return FALSE;
  }

  gint32 actual_width = (gint32)video_output_get_width(video_output);
  gint32 actual_height = (gint32)video_output_get_height(video_output);

  // mpv's render API is pull-based: the video output is configured only after
  // mpv_render_context_render() is called with a valid FBO. Before the first
  // frame the dimensions are unknown, so render into a 1x1 surface to let mpv
  // start decoding. The texture is resized on the next populate.
  gint32 required_width = actual_width > 0 ? actual_width : 1;
  gint32 required_height = actual_height > 0 ? actual_height : 1;

  gboolean notify_resize = FALSE;
  if (self->name == 0 || self->fbo == 0 ||
      self->current_width != (guint32)required_width ||
      self->current_height != (guint32)required_height) {
    if (self->name != 0) {
      glDeleteTextures(1, &self->name);
      self->name = 0;
    }
    if (self->fbo != 0) {
      glDeleteFramebuffers(1, &self->fbo);
      self->fbo = 0;
    }

    glGenFramebuffers(1, &self->fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, self->fbo);

    glGenTextures(1, &self->name);
    glBindTexture(GL_TEXTURE_2D, self->name);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, required_width, required_height, 0,
                 GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, self->name, 0);

    self->current_width = required_width;
    self->current_height = required_height;
    notify_resize = TRUE;
  } else {
    glBindFramebuffer(GL_FRAMEBUFFER, self->fbo);
    glBindTexture(GL_TEXTURE_2D, self->name);
  }

  mpv_render_context* render_context =
      video_output_get_render_context(video_output);
  mpv_opengl_fbo fbo{(gint32)self->fbo, required_width, required_height, 0};
  int flip_y = 0;
  mpv_render_param params[] = {
      {MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
      {MPV_RENDER_PARAM_FLIP_Y, &flip_y},
      {MPV_RENDER_PARAM_INVALID, NULL},
  };
  mpv_render_context_render(render_context, params);

  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glBindTexture(GL_TEXTURE_2D, 0);

  // Restore Flutter's context for the rest of the populate callback.
  eglMakeCurrent(flutter_display, flutter_draw, flutter_read, flutter_context);

  // Never publish zero dimensions: Flutter unmounts the Texture when the rect
  // is 0x0, and an unmounted texture stops receiving populate callbacks on
  // Linux, which would deadlock the render loop.
  if (notify_resize && actual_width > 0 && actual_height > 0) {
    video_output_notify_texture_update(video_output);
  }

  *target = GL_TEXTURE_2D;
  *name = self->name;
  *width = self->current_width;
  *height = self->current_height;
  return TRUE;
}
