.PHONY: test test-file lint

PLENARY ?= $(shell nvim --headless -c "lua io.write(vim.fn.stdpath('data') .. '/lazy/plenary.nvim')" -c "qa" 2>/dev/null)

test:
	nvim --headless -u NONE \
		-c "set rtp+=." \
		-c "set rtp+=$(PLENARY)" \
		-c "runtime plugin/plenary.vim" \
		-c "lua require('plenary.test_harness').test_directory('tests/', {minimal_init='tests/minimal_init.lua'})" \
		-c "qa"

test-file:
	nvim --headless -u NONE \
		-c "set rtp+=." \
		-c "set rtp+=$(PLENARY)" \
		-c "runtime plugin/plenary.vim" \
		-c "lua require('plenary.busted').run('$(FILE)')" \
		-c "qa"

lint:
	luacheck lua/ --globals vim --no-unused-args
