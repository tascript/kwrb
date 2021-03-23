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
#include "mrb_kwrb.h"

#define DONE mrb_gc_arena_restore(mrb, 0);

void mrb_kwrb_gem_init(mrb_state *mrb)
{
  struct RClass *kwrb;
  kwrb = mrb_define_class(mrb, "Kwrb", mrb->object_class);
  mrb_define_method(mrb, kwrb, "initialize", mrb_kwrb_init, MRB_ARGS_REQ(1));
  mrb_define_method(mrb, kwrb, "hello", mrb_kwrb_hello, MRB_ARGS_NONE());
  mrb_define_class_method(mrb, kwrb, "hi", mrb_kwrb_hi, MRB_ARGS_NONE());
  DONE;
}

void mrb_kwrb_gem_final(mrb_state *mrb)
{
}
