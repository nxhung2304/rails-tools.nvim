# Risks to test - #63

1. Real toggleterm, run a command twice.
   Test: install toggleterm, run `:Rails runner "puts 1"`, wait for exit, run it again. Expect one terminal window and no error.
2. Real toggleterm, buffer already gone (guess, medium confidence).
   Test: run `:Rails runner "puts 1"`, wait for exit, press a key so the buffer closes (or `:bd`), run it again. Expect no error and one terminal window.
3. Real toggleterm, toggle/show after exit (guess, low-medium confidence). Only reachable through a direct API call.
   Test: run a command, close its buffer after exit, run `:lua require("rails-tools.ui.terminal").toggle()`. Expect no new job and no command re-run.
4. Native terminal closed by the user after exit.
   Test: covered by the existing test "clears the active command when the terminal buffer is wiped".
5. Console reopened after it exited.
   Test: run the console, exit it, open the console again. Expect one terminal window and the dead buffer removed.
6. Sending text to an exited terminal now errors instead of warning (not reachable today, nothing calls send).
   Test: none needed now.
