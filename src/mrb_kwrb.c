/*
** mrb_kwrb.c - Kwrb class
**
** Copyright (c) Wataru Morita 2020
**
** See Copyright Notice in LICENSE
*/

#include "mruby.h"
#include "mruby/data.h"
#include "mrb_kwrb.h"

#define DONE mrb_gc_arena_restore(mrb, 0);

typedef struct {
  char *str;
  mrb_int len;
} mrb_kwrb_data;

static const struct mrb_data_type mrb_kwrb_data_type = {
  "mrb_kwrb_data", mrb_free,
};

static mrb_value mrb_kwrb_init(mrb_state *mrb, mrb_value self)
{
  mrb_kwrb_data *data;
  char *str;
  mrb_int len;

  data = (mrb_kwrb_data *)DATA_PTR(self);
  if (data) {
    mrb_free(mrb, data);
  }
  DATA_TYPE(self) = &mrb_kwrb_data_type;
  DATA_PTR(self) = NULL;

  mrb_get_args(mrb, "s", &str, &len);
  data = (mrb_kwrb_data *)mrb_malloc(mrb, sizeof(mrb_kwrb_data));
  data->str = str;
  data->len = len;
  DATA_PTR(self) = data;

  return self;
}

static mrb_value mrb_kwrb_hello(mrb_state *mrb, mrb_value self)
{
  mrb_kwrb_data *data = DATA_PTR(self);

  return mrb_str_new(mrb, data->str, data->len);
}

static mrb_value mrb_kwrb_hi(mrb_state *mrb, mrb_value self)
{
  return mrb_str_new_cstr(mrb, "hi!!");
}

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

