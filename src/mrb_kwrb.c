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
#include <stdlib.h>
#include <mruby/data.h>
#include "mrb_kwrb.h"
#include <pthread.h>

#define LIMIT 100

#define DONE mrb_gc_arena_restore(mrb, 0);

typedef struct
{
  char data[LIMIT];
  int head;
  int tail;
} kwrb_queue;

typedef struct
{
  pthread_t th;
} kwrb_thread;

const static struct mrb_data_type mrb_queue_type = {"Queue", mrb_free};
const static struct mrb_data_type mrb_thread_type = {"Thread", mrb_free};

static mrb_value
mrb_queue_init(mrb_state *mrb, mrb_value self)
{
  kwrb_queue *queue = (kwrb_queue *)mrb_malloc(mrb, sizeof(kwrb_queue));
  queue->head = 0;
  queue->tail = 0;
  DATA_TYPE(self) = &mrb_queue_type;
  DATA_PTR(self) = queue;
  return self;
}

static mrb_value mrb_enqueue(mrb_state *mrb, mrb_value self)
{
  char *message;
  int size;
  mrb_get_args(mrb, "s", &message, &size);
  int i;
  kwrb_queue *q;
  q = DATA_PTR(self);
  for (i = 0; i < size; i++)
  {
    if (q->tail >= LIMIT)
    {
      q->tail = 0;
    }
    q->data[q->tail] = message[i];
    q->tail++;
  }

  return mrb_nil_value();
}

static mrb_value mrb_dequeue(mrb_state *mrb, mrb_value self)
{
  kwrb_queue *q;
  q = DATA_PTR(self);
  if (q->head == q->tail)
  {
    return mrb_nil_value();
  }
  char result;
  result = q->data[q->head];
  q->head++;
  if (q->head >= LIMIT)
  {
    q->head = 0;
  }
  return mrb_str_new_static(mrb, &result, 1);
}

static void *mrb_thread_socket(void *p)
{
}

static mrb_value mrb_thread_init(mrb_state *mrb, mrb_value self)
{
  kwrb_thread *thread = (kwrb_thread *)mrb_malloc(mrb, sizeof(kwrb_thread));
  DATA_TYPE(self) = &mrb_thread_type;
  DATA_PTR(self) = thread;
  pthread_create(&thread->th, NULL, &mrb_thread_socket, &thread);
  return self;
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
  mrb_define_method(mrb, thread, "initialize", mrb_thread_init, MRB_ARGS_NONE());

  DONE;
}

void mrb_kwrb_gem_final(mrb_state *mrb)
{
}
