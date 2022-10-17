# Zigtris

Any of the following commands will produce a more than decent binary.

```console
zig build -Drelease-safe
zig build -Drelease-small
zig build -Drelease-fast
```

Enjoy!

# Quick showcase

![Zigtris](./zigtris.png)

The numbers displayed are lines cleared and time passed respectively.

# Controls

| Key | Action |
| --- | --- |
| Escape | Quit game |
| Tab | Next colorscheme |
| Backspace | Previous colorscheme |
| R | Reset game (restart) |
| Right Control | Hold piece |
| A | Rotate left |
| D | Rotate spin |
| Up | Rotate right |
| Left | Move left |
| Right | Move right |
| Down | Move down |
| Space | Hard drop |
| {1,2,3} | Switch to {Solid,Gridless,Edges} style drawing respectively |

# Customization

Currently, there are no plans to add a configuration file. However, I am not
entirely opposed to the idea.

In order to customize Zigtris, here are a few helpful pointers:

## Keys, and the key repeating behavior

In the **Keyboard** structure are two variables, `initial_delay` and
`repeat_delay`. Both are used to determine whether a held down key should
repeat or not. The initial delay waits a number of time units before
activating the repeating behavior. Then the `repeat_delay` is used to determine
the number of keys per time unit.

As per default, they only affect **Left**, **Right**, and **Down** arrow keys.

Look for `SDL_SCANCODE_` to see all the keys and customize to your liking.

## Font

The default is a JetBrainsMono variant. Simply replace `./assets/font.ttf` to
change it.

## Colors

In-game you can cycle through the colorschemes by pressing **Tab** or
**Backspace**. The default colors are **habamax**, **gruvbox dark**, **gruvbox
light**, **onedark**, and catppuccin **macchiato**. These are all popular
colorschemes used by programmers. Feel free to add new ones, perhaps even make
a pull request.

## Style

The drawing style for pieces is very simple. I hope to keep it as simple as
possible, while still having some variety. That said, there is a **Style**
enumeration which could be expanded on. Feel free to suggest changes.

#
