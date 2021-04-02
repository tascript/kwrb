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
#include <mruby/data.h>
#include "mrb_kwrb.h"

#define LIMIT 100

#define DONE mrb_gc_arena_restore(mrb, 0);

typedef struct {
  char data[LIMIT];
  int head;
  int tail;
} kwrb_queue

const static struct mrb_data_type mrb_queue_type = { "Queue", mrb_free }

static mrb_value mrb_queue_generator(mrb_state *mrb, mrb_value self) {
  kwrb_queue *queue = malloc(sizeof(kwrb_queue));
  queue->head = 0;
  queue->tail = 0;
  for (i = 0; i < LIMIT; i++) {
    queue->data[i] = '';
  }
  return self;
}

static mrb_value mrb_enqueue(mrb_state *mrb, mrb_value self) {
  mrb_value message;
  mrb_get_args(mrb, "S", &message);
  return mrb_nil_value();
}

static mrb_value mrb_dequeue(mrb_state *mrb, mrb_value self) {
}

void mrb_kwrb_gem_init(mrb_state *mrb) {
  struct RClass *queue;
  queue = mrb_define_class(mrb, "Queue", mrb->object_class);
  MRB_SET_INSTANCE_TT(queue, MRB_TT_DATA);
  mrb_define_method(mrb, queue, "initialize", mrb_queue_generator, MRB_ARGS_NONE());
  mrb_define_method(mrb, queue, "enqueue", mrb_enqueue, MRB_ARGS_REQ(1));
  mrb_define_method(mrb, queue, "dequeue", mrb_dequeue, MRB_ARGS_NONE());
  DONE;
}

void mrb_kwrb_gem_final(mrb_state *mrb) {
}
