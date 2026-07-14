#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <ctype.h>
#include <string.h>
#include <assert.h>

const size_t MAX_FORM_NAME_LEN = 32;

struct line_info {
  uint32_t depth;
  bool all_whitespace;
};

struct state {
  enum {
    IN_INDENTED,
    IN_COMMENT,
    AFTER_HASH,
    IN_STRING,
    IN_FORM_NAME,
    AFTER_FORM_NAME,
    STRING_ESCAPE,
    AFTER_HASH_BACKSLASH,
  } type;
  union {
    struct {
      uint32_t depth;
    } in_indented;
    struct {
      uint32_t depth;
      uint32_t form_name_len;
      char* form_name;
    } in_form_name;
  };
};

const char* const SPECIAL_FORMS[] = {
  "define",
  "if",
  "let",
  "let*",
  "letrec",
  "case",
  "cond",
  "lambda",
  "set!",
  "unless",
  "when",
};

bool is_special_form(char* form_name, uint32_t form_name_len) {
  if (form_name_len == 0)
    return false;
  for (size_t i = 0; i < sizeof(SPECIAL_FORMS) / sizeof(*SPECIAL_FORMS); i++)
    if (strncmp(form_name, SPECIAL_FORMS[i], form_name_len) == 0)
      if (strlen(SPECIAL_FORMS[i]) == form_name_len)
        return true;
  return false;
}

char next_char() {
  if (feof(stdin)) return 0;
  char c = fgetc(stdin);
  if (c == EOF) return 0;
  return c;
}
void put_char(struct line_info* line_info, char c) {
  if (c == '\n') {
    line_info->depth = 0;
    line_info->all_whitespace = true;
  } else {
    line_info->depth += 1;
  }
  line_info->all_whitespace = line_info->all_whitespace && isspace(c);
  fputc(c, stdout);
}
void put_char_repeat(struct line_info* line_info, char c, uint32_t n) {\
  while (n-- > 0)
    put_char(line_info, c);
}

void loop(struct state state, struct line_info* line_info) {
  char c;
  while ((c = next_char())) {
  again:
    if (state.type == IN_INDENTED) {
      uint32_t missing_depth = state.in_indented.depth < line_info->depth ? 0 : state.in_indented.depth - line_info->depth;
      if (c == ' ') {
        if (0 >= missing_depth && line_info->all_whitespace)
          continue;
        put_char(line_info, ' ');
        continue;
      }
      if (isspace(c)) {
        put_char(line_info, c);
        continue;
      }
      if (c == ';') {
        put_char(line_info, ';');
        loop((struct state) { .type = IN_COMMENT }, line_info);
        continue;
      }

      uint32_t prefix = 0 >= missing_depth || !line_info->all_whitespace ? 0 : missing_depth;
      uint32_t opening_paren_depth = line_info->depth;
      put_char_repeat(line_info, ' ', prefix);
      put_char(line_info, c);
      if (c == '#') {
        loop((struct state) { .type = AFTER_HASH }, line_info);
        continue;
      }
      if (c == '"') {
        loop((struct state) { .type = IN_STRING }, line_info);
        continue;
      }
      if (c == '(' || c == '[') {
        char* form_name = alloca(MAX_FORM_NAME_LEN);
        loop((struct state) {
          .type = IN_FORM_NAME,
          .in_form_name.depth = opening_paren_depth + prefix,
          .in_form_name.form_name = form_name,
          .in_form_name.form_name_len = 0,
        }, line_info);
        continue;
      }
      if (c == ')' || c == ']') {
        return;
      }
      continue;
    }
    if (state.type == IN_FORM_NAME) {
      if (strchr("\n ([\")]#;,\\`", c) != NULL) {
        state.type = AFTER_FORM_NAME;
        goto again;
      } else {
        put_char(line_info, c);
        if (state.in_form_name.form_name_len < MAX_FORM_NAME_LEN) {
          state.in_form_name.form_name[state.in_form_name.form_name_len++] = c;
        }
        continue;
      }
    }
    if (state.type == AFTER_FORM_NAME) {
      if (c == ' ') continue;
      if (c == ';') {
        put_char(line_info, c);
        loop((struct state) {
          .type = IN_COMMENT,
        }, line_info);
        continue;
      }
      if (c == '\n') {
        put_char(line_info, c);
        state.type = IN_INDENTED;
        state.in_indented.depth = 2 + state.in_form_name.depth;
        continue;
      }
      bool gap = !(c == ')' || c == ']' || state.in_form_name.form_name_len == 0);
      uint32_t indentation = is_special_form(state.in_form_name.form_name, state.in_form_name.form_name_len)
          ? 2 + state.in_form_name.depth
          : line_info->depth + (gap ? 1 : 0);
      if (gap) put_char(line_info, ' ');
      state.type = IN_INDENTED;
      state.in_indented.depth = indentation;
      goto again;
    }
    if (state.type == IN_COMMENT) {
      if (c == '\n')
        return;
      put_char(line_info, c);
      continue;
    }
    if (state.type == AFTER_HASH) {
      put_char(line_info, c);
      if (c == '\\') {
        state.type = AFTER_HASH_BACKSLASH;
        continue;
      } else {
        return;
      }
    }
    if (state.type == AFTER_HASH_BACKSLASH) {
      put_char(line_info, c);
      return;
    }
    if (state.type == IN_STRING) {
      put_char(line_info, c);
      if (c == '"')
        return;
      if (c == '\\')
        loop((struct state) { .type = STRING_ESCAPE }, line_info);
      continue;
    }
    if (state.type == STRING_ESCAPE) {
      put_char(line_info, c);
      return;
    }
    fprintf(stderr, "state.type: %d\n", state.type);
    assert(0 && "UNKNOWN STATE");
  }
}

int main() {
  struct line_info line_info = { 0, true };
  struct state state = {
    .type = IN_INDENTED,
    .in_indented = { .depth = 0 },
  };

  loop(state, &line_info);
}

