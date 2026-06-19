# Rules for developing with Flux

1. If you don't have it in context already, read `Flux_Language_Manual.md` to understand the language design.

2. The goals listed inside of the Flux Language Manual are the goals for the language, keep it to the book. If you're every unsure on how to tackle something, ask the user about it. Clarify what you *think* it says. Update `copilot-instructions.md` if you find something else new, add it in the `items to remember` section below

3. Flux is already installed. EVERY app must work in either AOT or JIT mode. If something is designed to only run in AOT / JIT mode, label the top of the file with either `// DOCTYPE {AOT}` OR `// DOCTYPE {JIT}`. If it's designed to work in both, no label is needed.

# Developing StratOS

1. The bootloader should be written in either Assembly or Flux, but the rest of the OS should be written in Flux. The OS should be designed to run in AOT mode, but it apps inside of it should also be able to run in JIT mode for testing and development purposes.

2. The terminal should be bash like, and come pre-installed with Flux, and the Flux REPL (just the command `flux`) should be available as a command in the terminal.

3. The OS should have a windowing system with snapping controls, expansive settings, a taskbar, and very basic drivers *(they can be pulled from Linux if needed)*. The OS should have the following pre-installed apps: a text editor, a file explorer, a web browser, and a music player. The OS should also have a package manager for installing new apps, named `quantum`.

4. QEMU is installed, use this to your advantage to collect data about how the OS is working, it should be bootable in UEFI / legacy, run under x86, and support Intel and AMD processors. Ensure you shut down the OS after finishing testing to avoid data loss.

5. For icons, you should draw them using SVGs, then render them *(you can use an external language / library such as python to render them, and save them as .jpg or .png files)*.

6. The filesystem should be neatly arranged, and avoid creating manual / additional markdown files everywhere.

## Items to remember

### Module Imports
- Always import `std.sys` when using `thread.sleep()` or other system functions
- Audio requires `std.audio` import
- Graphics requires `std.graphics` import
- Multiple modules can be imported together

### Audio System
- Must call `Audio.init()` before using any audio functions
- Use `Audio.generateTone(frequency, duration)` to create procedural sounds
- Sound IDs are returned and can be played with `Audio.playSound(id, loops)`
- Always call `Audio.quit()` at the end for cleanup
- Volume control: `Audio.setSoundVolume(id, volume)` where volume is 0-128

### Graphics System
- Window creation: `Window win = Window("Title", width, height);`
- Main loop should check `win.isOpen()` and call `win.pollEvents()`
- Drawing methods: `fillRect()`, `drawLine()`, `drawCircle()`, etc.
- Always call `win.present()` to display the rendered frame
- Mouse input: `win.mouseButtonPressed(button)` and `win.getMousePos()` returns a list `[x, y]`
- Keyboard input: `win.keyPressed("KEY")` for checking key states
- Clear screen: `win.clear(r, g, b)` with RGB values 0-255

### Lists and Arrays
- Lists are dynamic: `list myList = [];`
- Add elements: `myList.add(value)`
- Access by index: `myList[i]`
- Get length: `myList.length` (property, not method)
- Lists can contain any type

### Control Flow
- Use `elif` (preferred) or `else if` for chained conditions
- `for` loops support both C-style and for-each: `for (item in list)`
- `while` and `do-while` loops available
- `break` and `continue` work as expected

### Functions
- Return type annotation: `func name() -> type`
- No return type annotation defaults to `int` and returns 0
- Named parameters supported: `func(param: value)`
- Default parameters: `func name(param = default)`

### Type System
- Explicit typing required: `int x = 10;`
- Type re-declaration allows changing types: `x = string = "ten";`
- Casting: `(int) value`, `(float) value`, etc.
- No implicit type conversion

### Thread and Timing
- `thread.sleep(milliseconds)` for delays
- Requires `std.sys` import

### Common Patterns
- Window event loop pattern: `while (win.isOpen()) { win.pollEvents(); ... win.present(); }`
- Mouse click debouncing: add `thread.sleep(200)` after detecting click
- Target ~60 FPS with `thread.sleep(16)` at end of frame

