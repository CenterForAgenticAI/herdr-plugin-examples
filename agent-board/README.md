# Agent Board: a Herdr desktop-region demo

Agent Board keeps a list of every agent in the Herdr session on the right edge of the window, or in a strip along the bottom. It stays put when you switch tabs or workspaces. Press an agent's number to jump to it.

It needs a Herdr build with desktop regions ([`feat/desktop-regions-v2`](https://github.com/CenterForAgenticAI/herdr/tree/feat/desktop-regions-v2) in the CenterForAgenticAI fork), plus `bash` and `jq`.

## Try it

```bash
herdr plugin install CenterForAgenticAI/herdr-plugin-examples/agent-board
herdr region open demo.agent-board board
```

To work on a local copy instead, run `herdr plugin link /path/to/agent-board`.

For the bottom strip instead, or as well:

```bash
herdr region open demo.agent-board strip
```

Or run a toggle action, which opens the region or closes it:

```bash
herdr plugin action invoke demo.agent-board.toggle        # right edge
herdr plugin action invoke demo.agent-board.toggle-strip  # bottom
```

To bind the toggle to a key, add this to `config.toml`:

```toml
[[keys.command]]
key = "prefix+a"
type = "plugin_action"
command = "demo.agent-board.toggle"
description = "agent board"
```

## Using the board

Click the board, or bind `keys.focus_region`, to give it the keyboard.

- `1`–`9` focus that agent's pane. The board gives the keyboard back to the pane.
- `r` refreshes now. The board also refreshes every 2 seconds.
- `h` hides the board. Its process keeps running; `herdr region show <region_id>` or `keys.toggle_region` brings it back.

Blocked agents sort first and are counted in the header. Then come working, done and idle agents.

Drag the board's inner border to resize it. The manifest allows 24 to 60 columns for the board, and 4 to 20 rows for the strip, whose top border is the one to drag. `keys.toggle_bottom_region` and `keys.focus_bottom_region` act on the strip.

## What it shows about regions

- One region slot per edge: a second `region open` returns `region_slot_occupied`.
- The region is not a pane: it never appears in `herdr pane list` or `herdr agent list`, so the board does not list itself.
- Disabling or unlinking the plugin closes the board and stops its process.
- The board survives a Herdr restart: the session snapshot reopens it.
