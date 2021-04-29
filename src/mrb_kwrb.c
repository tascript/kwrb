/*
** mrb_kwrb.c - Kwrb class
**
** Copyright (c) Wataru Morita 2020
**
** See Copyright Notice in LICENSE
*/

#include <mruby.h>
#include <mruby/error.h>
#include <mruby/class.h>
#include <mruby/value.h>
#include <mruby/string.h>
#include <mruby/array.h>
#include <stdlib.h>
#include <mruby/data.h>
#include "mrb_kwrb.h"
#include <pthread.h>

#define LIMIT 100

#define DONE mrb_gc_arena_restore(mrb, 0);

typedef struct
{
  mrb_state *mrb;
  mrb_value queue;
} kwrb_queue;

typedef struct
{
  pthread_t th;
  mrb_state *mrb;
  mrb_value block;
} kwrb_thread;

const static struct mrb_data_type mrb_queue_type = {"Queue", mrb_free};
const static struct mrb_data_type mrb_thread_type = {"Thread", mrb_free};

static mrb_value
mrb_queue_init(mrb_state *mrb, mrb_value self)
{
  kwrb_queue *q = (kwrb_queue *)mrb_malloc(mrb, sizeof(kwrb_queue));
  q->mrb = mrb;
  q->queue = mrb_ary_new(mrb);
  DATA_TYPE(self) = &mrb_queue_type;
  DATA_PTR(self) = q;
  return self;
}

static mrb_value mrb_enqueue(mrb_state *mrb, mrb_value self)
{
  mrb_value message;
  mrb_get_args(mrb, "S", &message);
  kwrb_queue *q;
  q = DATA_PTR(self);
  int arena_i = mrb_gc_arena_save(q->mrb);
  mrb_ary_push(q->mrb, q->queue, message);
  mrb_gc_arena_restore(q->mrb, arena_i);

  return mrb_nil_value();
}

static mrb_value mrb_dequeue(mrb_state *mrb, mrb_value self)
{
  kwrb_queue *q;
  mrb_value res;
  q = DATA_PTR(self);
  res = mrb_ary_pop(q->mrb, q->queue);
  return res;
}

static void *mrb_thread_socket(void *p)
{
  kwrb_thread *thread = (kwrb_thread *)p;
  mrb_yield_argv(thread->mrb, thread->block, 0, NULL);
}

static mrb_value mrb_thread_init(mrb_state *mrb, mrb_value self)
{
  kwrb_thread *thread = (kwrb_thread *)mrb_malloc(mrb, sizeof(kwrb_thread));
  DATA_TYPE(self) = &mrb_thread_type;
  DATA_PTR(self) = thread;
  mrb_get_args(mrb, "&", &thread->block);
  pthread_create(&thread->th, NULL, &mrb_thread_socket, &thread);
  return self;
}

static mrb_value mrb_thread_join(mrb_state *mrb, mrb_value self)
{
  kwrb_thread *t;
  pthread_join(t->th, NULL);
  return mrb_nil_value();
}

void mrb_kwrb_gem_init(mrb_state *mrb)
{
  struct RClass *queue, *thread;

  queue = mrb_define_class(mrb, "Queue", mrb->object_class);
  MRB_SET_INSTANCE_TT(queue, MRB_TT_DATA);
  mrb_define_method(mrb, queue, "initialize", mrb_queue_init, MRB_ARGS_NONE());
  mrb_define_method(mrb, queue, "enqueue", mrb_enqueue, MRB_ARGS_REQ(1));
  mrb_define_method(mrb, queue, "dequeue", mrb_dequeue, MRB_ARGS_NONE());

  thread = mrb_define_class(mrb, "Thread", mrb->object_class);
  MRB_SET_INSTANCE_TT(thread, MRB_TT_DATA);
  mrb_define_method(mrb, thread, "initialize", mrb_thread_init, MRB_ARGS_REQ(1));
  mrb_define_method(mrb, thread, "join", mrb_thread_join, MRB_ARGS_REQ(2));

  DONE;
}

void mrb_kwrb_gem_final(mrb_state *mrb)
{
}
