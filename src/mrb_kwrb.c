/*
** mrb_kwrb.c - Kwrb class
**
** Copyright (c) Wataru Morita 2020
**
** See Copyright Notice in LICENSE
*/

#include <mruby.h>
#include <mruby/error.h>
#include <mruby/string.h>
#include <stdlib.h>
#include "mrb_kwrb.h"

#define LIMIT 100

#define DONE mrb_gc_arena_restore(mrb, 0);

static mrb_value mrb_queue_generator(mrb_state *mrb, mrb_value self) {
  char *queue = (char *)malloc(LIMIT * sizeof(char));
  for (i = 0; i < LIMIT; i++) {
    queue[i] = '';
  }
}

void mrb_kwrb_gem_init(mrb_state *mrb) {
  struct RClass *queue;
  queue = mrb_define_class(mrb, "Queue", mrb->object_class);
  mrb_define_method(mrb, queue, "initialize", mrb_queue_generator, MRB_ARGS_NONE());
  DONE;
}

void mrb_kwrb_gem_final(mrb_state *mrb) {
}
