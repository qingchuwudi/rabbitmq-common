PROJECT = rabbit_common
PROJECT_DESCRIPTION = Modules shared by rabbitmq-server and rabbitmq-erlang-client

LOCAL_DEPS = compiler syntax_tools xmerl
BUILD_DEPS = rabbitmq_codegen
DEPS = lager jsx
TEST_DEPS = proper

.DEFAULT_GOAL = all

EXTRA_SOURCES += include/rabbit_framing.hrl				\
		 src/rabbit_framing_amqp_0_8.erl			\
		 src/rabbit_framing_amqp_0_9_1.erl

.DEFAULT_GOAL = all
$(PROJECT).d:: $(EXTRA_SOURCES)

# FIXME: Use erlang.mk patched for RabbitMQ, while waiting for PRs to be
# reviewed and merged.

ERLANG_MK_REPO = https://github.com/rabbitmq/erlang.mk.git
ERLANG_MK_COMMIT = rabbitmq-tmp

include mk/rabbitmq-components.mk
include erlang.mk
include mk/rabbitmq-build.mk
include mk/rabbitmq-dist.mk
include mk/rabbitmq-tools.mk

# --------------------------------------------------------------------
# Framing sources generation.
# --------------------------------------------------------------------

PYTHON       ?= python
CODEGEN       = $(CURDIR)/codegen.py
CODEGEN_DIR  ?= $(DEPS_DIR)/rabbitmq_codegen
CODEGEN_AMQP  = $(CODEGEN_DIR)/amqp_codegen.py

AMQP_SPEC_JSON_FILES_0_8   = $(CODEGEN_DIR)/amqp-rabbitmq-0.8.json
AMQP_SPEC_JSON_FILES_0_9_1 = $(CODEGEN_DIR)/amqp-rabbitmq-0.9.1.json	\
			     $(CODEGEN_DIR)/credit_extension.json

include/rabbit_framing.hrl:: $(CODEGEN) $(CODEGEN_AMQP) \
    $(AMQP_SPEC_JSON_FILES_0_9_1) $(AMQP_SPEC_JSON_FILES_0_8)
	$(gen_verbose) env PYTHONPATH=$(CODEGEN_DIR) \
	 $(PYTHON) $(CODEGEN) --ignore-conflicts header \
	 $(AMQP_SPEC_JSON_FILES_0_9_1) $(AMQP_SPEC_JSON_FILES_0_8) $@

src/rabbit_framing_amqp_0_9_1.erl:: $(CODEGEN) $(CODEGEN_AMQP) \
    $(AMQP_SPEC_JSON_FILES_0_9_1)
	$(gen_verbose) env PYTHONPATH=$(CODEGEN_DIR) \
	 $(PYTHON) $(CODEGEN) body $(AMQP_SPEC_JSON_FILES_0_9_1) $@

src/rabbit_framing_amqp_0_8.erl:: $(CODEGEN) $(CODEGEN_AMQP) \
    $(AMQP_SPEC_JSON_FILES_0_8)
	$(gen_verbose) env PYTHONPATH=$(CODEGEN_DIR) \
	 $(PYTHON) $(CODEGEN) body $(AMQP_SPEC_JSON_FILES_0_8) $@

clean:: clean-extra-sources

clean-extra-sources:
	$(gen_verbose) rm -f $(EXTRA_SOURCES)
