# Risks to test (#62)

- Blank line or group-level line below a multi-line let or an example without a block must still focus the parent group. Tests: "targets the parent group from a blank line below a multi-line let", "... below a multi-line example without a block".
- A multi-line call that opens a block but is not a target (shared_examples) must not pick a sibling above. Test: "targets the parent group when a multi-line call that opens a block is not a target".
- A ` #` inside a string on a closing-bracket line may hide the block opener; falls back to today's behaviour (focuses the group). Not a regression from main. No test (accepted).
- Heredoc-like text inside a quoted string is not filtered and may swallow lines up to the cursor, so a wrong example above can be focused. Accepted in spec. No test (accepted).
- Unspaced shovel (list<<item) and similar left-shift or append forms must not be read as heredocs. Tests: "does not treat a shovel operator without spaces as a heredoc", "does not skip the lines below a quoted string appended without a space", "... a left shift by a constant".
- Heredoc opener in a comment, regex or =begin block must be ignored. Tests: "does not treat a heredoc opener in a trailing comment as a heredoc", "... in a regex", "... inside a =begin block".
- Heredoc with a dedented end line, two heredocs on one line, quoted names with dash or spaces. Tests: "targets the example around a heredoc with a dedented end line", "skips the bodies of two heredocs opened on one line", "skips a heredoc whose quoted name has a dash".
- Cost: one extra read of lines 1..cursor per call; is_focused has no caller today. No test.
