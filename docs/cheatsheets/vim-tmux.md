# Vim and tmux Cheat Sheet

Quick reference for editing in vim and managing terminal sessions with tmux.
Chapters: [Vim essentials](../chapters/01-command-line/09-vim-essentials.md),
[tmux](../chapters/01-command-line/10-tmux.md).

Mint ships only `vim-tiny`. Install the full editor and tmux with
`sudo apt install vim tmux`.

## Vim: survival kit

| Keys | What it does |
|---|---|
| ++esc++ | Back to Normal mode (press it whenever you're unsure) |
| `:w` ++enter++ | Save |
| `:q` ++enter++ | Quit (fails if there are unsaved changes) |
| `:wq` or `:x` or `ZZ` | Save and quit |
| `:q!` or `ZQ` | Quit and **discard** changes |
| `u` / ++ctrl+r++ | Undo / redo |
| `:help topic` | Built-in help (`:q` to close it) |
| `vimtutor` | A 30-minute interactive tutorial (run in the shell) |

## Vim: modes

| Mode | How to enter | What it's for |
|---|---|---|
| **Normal** | ++esc++ | Moving and running commands (the default) |
| **Insert** | `i`, `a`, `o`, … | Typing text |
| **Visual** | `v` (characters), `V` (lines), ++ctrl+v++ (block) | Selecting text |
| **Command-line** | `:` | Ex commands: save, quit, substitute |
| **Replace** | `R` | Overwrite text |

## Vim: entering Insert mode

| Keys | Start inserting… |
|---|---|
| `i` / `a` | Before / after the cursor |
| `I` / `A` | At the start / end of the line |
| `o` / `O` | On a new line below / above |
| `cw` / `cc` / `C` | Replacing a word / the whole line / to end of line |
| `s` | Replacing one character |

## Vim: motions

| Keys | Moves to |
|---|---|
| `h` `j` `k` `l` | Left, down, up, right |
| `w` / `b` / `e` | Next word start / previous word start / word end |
| `W` / `B` / `E` | Same, for space-separated WORDS |
| `0` / `^` / `$` | Line start / first non-blank / line end |
| `gg` / `G` | First line / last line |
| `42G` or `:42` | Line 42 |
| `f,` / `t,` | Onto / just before the next `,` on this line (`;` repeats) |
| `%` | Matching bracket `()` `[]` `{}` |
| `{` / `}` | Previous / next blank line (paragraph) |
| ++ctrl+d++ / ++ctrl+u++ | Half a page down / up |
| ++ctrl+o++ / ++ctrl+i++ | Back / forward in the jump list |
| `*` / `#` | Next / previous occurrence of the word under the cursor |

Prefix a count to repeat: `5j` moves down 5 lines, `3w` 3 words.

## Vim: operators (verb + motion)

Vim commands are a grammar: **operator** + **motion** or **text object**.
`d` + `w` deletes a word; `c` + `i"` changes inside quotes.

| Operator | Meaning | Examples |
|---|---|---|
| `d` | Delete (and save to a register, like cut) | `dw` word, `dd` line, `d$` or `D` to end, `dG` to end of file |
| `c` | Change: delete, then Insert mode | `cw`, `cc`, `ci(` |
| `y` | Yank (copy) | `yw`, `yy` line, `y$` |
| `>` / `<` | Indent / unindent | `>>` line, `>}` paragraph |
| `gU` / `gu` | Uppercase / lowercase | `gUiw` |
| `=` | Auto-indent | `=G`, `gg=G` whole file |

| Single keys | What it does |
|---|---|
| `x` | Delete the character under the cursor |
| `p` / `P` | Paste after / before the cursor (or below / above the line) |
| `r` + char | Replace one character |
| `J` | Join the next line onto this one |
| `.` | **Repeat the last change**: the most useful key in vim |
| `~` | Toggle case |

## Vim: text objects

Use after an operator, or in Visual mode. `i` = inside, `a` = around
(includes the delimiters or surrounding space).

| Object | Selects | Example |
|---|---|---|
| `iw` / `aw` | Word | `diw` delete word under cursor |
| `i"` / `a"` | Inside / around double quotes | `ci"` replace a string |
| `i'`, `` i` `` | Single quotes, backticks | `di'` |
| `i(` or `ib` / `a(` | Parentheses | `ci(` replace function arguments |
| `i{` or `iB` | Braces | `di{` empty a block |
| `i[` / `i<` | Brackets, angle brackets | `yi[` |
| `it` / `at` | HTML/XML tag contents | `cit` |
| `ip` / `ap` | Paragraph | `dap` delete a paragraph |

## Vim: search and replace

| Command | What it does |
|---|---|
| `/error` | Search forward (`n` next, `N` previous) |
| `?error` | Search backward |
| `:noh` | Clear search highlighting |
| `:s/old/new/` | Replace the first match on this line |
| `:s/old/new/g` | Replace all on this line |
| `:%s/old/new/g` | Replace all in the file |
| `:%s/old/new/gc` | Same, confirming each one |
| `:10,20s/^/# /` | Comment out lines 10–20 |
| `:'<,'>s/a/b/g` | Replace in the visual selection (typing `:` in Visual mode inserts `'<,'>`) |
| `:g/DEBUG/d` | Delete every line containing `DEBUG` |
| `:v/ERROR/d` | Delete every line **not** containing `ERROR` |

## Vim: files, buffers, windows

| Command | What it does |
|---|---|
| `:e path` | Open a file |
| `:w path` | Save as |
| `:w !sudo tee %` | Save a file you opened without `sudo` (then reload with `:e!`) |
| `:r file` / `:r !date` | Insert a file / a command's output |
| `:ls`, `:bn`, `:bp` | List, next, previous buffer |
| `:sp file` / `:vsp file` | Split horizontally / vertically |
| ++ctrl+w++ `w` | Cycle between splits (++ctrl+w++ + `h`/`j`/`k`/`l` to move) |
| `:set nu` / `:set rnu` | Line numbers / relative numbers |
| `:set paste` | Paste without auto-indent mangling (`:set nopaste` after) |
| `q` + letter … `q`, then `@` + letter | Record a macro, then play it (`@@` repeats) |

## Vim: a starter `~/.vimrc`

```vim title="~/.vimrc"
syntax on
filetype plugin indent on
set number relativenumber
set expandtab tabstop=4 shiftwidth=4
set ignorecase smartcase incsearch hlsearch
set scrolloff=5
set mouse=a
set undofile
set undodir=~/.vim/undo//
```

Create the undo directory once with `mkdir -p ~/.vim/undo`.

## tmux: concepts

**tmux** is a terminal multiplexer. A **session** is a set of **windows**
(like tabs); each window is split into **panes**. Sessions keep running on
the server when you **detach** or your SSH connection drops.

All key bindings start with the **prefix**, ++ctrl+b++ by default. "Prefix
`c`" means press ++ctrl+b++, release, then press `c`.

## tmux: sessions (from the shell)

| Command | What it does |
|---|---|
| `tmux` | Start a new session |
| `tmux new -s work` | Start a session named `work` |
| `tmux new -A -s work` | Attach to `work`, or create it if it doesn't exist |
| `tmux ls` | List sessions |
| `tmux attach -t work` | Reattach to `work` (`tmux a` attaches to the last one) |
| `tmux kill-session -t work` | End a session |
| `tmux kill-server` | End all sessions |

## tmux: key bindings

| Keys | What it does |
|---|---|
| Prefix `d` | **Detach** (the session keeps running) |
| Prefix `s` | Choose a session interactively |
| Prefix `$` | Rename the session |
| Prefix `c` | New window |
| Prefix `,` | Rename the window |
| Prefix `n` / `p` | Next / previous window |
| Prefix `0`…`9` | Go to window number |
| Prefix `w` | Choose a window from a list |
| Prefix `&` | Kill the window (asks first) |
| Prefix `%` | Split into left and right panes |
| Prefix `"` | Split into top and bottom panes |
| Prefix arrow keys | Move to the pane in that direction |
| Prefix `o` | Next pane |
| Prefix `;` | Last active pane |
| Prefix `z` | Zoom the pane to full window, and back |
| Prefix `x` | Kill the pane (asks first) |
| Prefix `!` | Break the pane out into its own window |
| Prefix ++ctrl+up++ etc. | Resize the pane by one cell (++alt++ + arrow: by five) |
| Prefix ++space++ | Cycle through pane layouts |
| Prefix `q` | Show pane numbers |
| Prefix `[` | Enter **copy mode** (scroll back through output) |
| Prefix `]` | Paste the last copied text |
| Prefix `:` | tmux command prompt |
| Prefix `?` | List all key bindings |

## tmux: copy mode

Prefix `[` enters copy mode. Use the arrow keys, ++page-up++ and
++page-down++ to scroll, and `q` to leave. With `mode-keys vi` (see the
config below):

| Keys | What it does |
|---|---|
| `/` / `?` | Search down / up (`n`, `N` repeat) |
| ++space++ | Start a selection |
| ++enter++ | Copy the selection and leave copy mode |
| `g` / `G` | Top / bottom of the history |

## tmux: a starter `~/.tmux.conf`

```text title="~/.tmux.conf"
set -g mouse on                 # click panes, drag borders, scroll with the wheel
set -g history-limit 50000      # more scrollback
set -g base-index 1             # windows start at 1, matching the keyboard
setw -g pane-base-index 1
setw -g mode-keys vi            # vi keys in copy mode
set -sg escape-time 10          # no delay after Esc (important for vim)

# Split with | and -, opening in the current directory
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Reload this file with prefix r
bind r source-file ~/.tmux.conf \; display "config reloaded"
```

Reload a changed config in a running session with prefix `:` then
`source-file ~/.tmux.conf`.

!!! tip "The SSH habit"
    On any remote server, run `tmux new -A -s main` right after you log in.
    If your connection drops in the middle of a long upgrade or a big
    `rsync`, log back in and run the same command to pick up exactly where
    you left off.
