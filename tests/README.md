# Candidate panel regression test

After preparing the normal Squirrel build dependencies, run on a Mac with an active display:

```sh
bash tests/vertical-auto-reverse.sh
```

Set `DEVELOPER_DIR` if Xcode is not the selected developer directory. Optionally set
`SQUIRREL_TEST_SCREENSHOTS` to an existing directory to save rendered panel images.

The test compiles the production panel, view, theme, configuration reader and key
mapper. It loads an isolated temporary Rime configuration and uses a controller
stub, so it does not register an input source or access the user's Rime data.

It checks normal/reversed placement, candidate identity and mouse hit testing,
highlight/hover indices, custom labels, preedit, wrapping, candidate-count changes,
theme overrides, excluded layouts, fullscreen, empty state and key mapping. It runs
the placement checks on every connected screen. Real application input and commits
still require manual verification after installing the input method.
