**FLUX**

PROGRAMMING LANGUAGE

REFERENCE MANUAL

_"From the Void, Structure."_

Version 0.1

The Native Interface for StratOS

Multi-Paradigm | Systems-Level | Visual-First | C++ Interoperable

  

# **Table of Contents**

|     |     |     |
| --- | --- | --- |
| **#** | **Chapter** | **Page** |
| 1.  | Introduction & Philosophy | 4   |
| 2.  | Getting Started | 5   |
| 3.  | The Compiler & Runtime Environment | 6   |
| 4.  | Lexical Structure & Syntax | 9   |
| 5.  | The Type System | 12  |
| 6.  | Variables & Constants | 15  |
| 7.  | Operators & Logic | 17  |
| 8.  | Control Flow | 21  |
| 9.  | Functions, Methods & Closures | 25  |
| 10. | Object-Oriented Programming | 29  |
| 11. | Error Handling & Safety | 33  |
| 12. | Concurrency | 35  |
| 13. | Networking & I/O | 37  |
| 14. | Mathematics & Physics | 40  |
| 15. | Memory Management & Pointers | 42  |
| 16. | Graphics & StratOS Internals | 45  |
| 17. | Interoperability (C++ Bridge) | 48  |
| 18. | Standard Library Reference | 50  |
| 19. | StratOS Desktop Environment | 54  |
| 20. | Native Code Execution | 60  |
| 21. | Persistent Storage & Networking | 62  |
| Appendix A | Operator Precedence Table | 58  |
| Appendix B | Reserved Keywords | 58  |
| Appendix C | Primitive Type Reference | 59  |

  

# **1\. Introduction & Philosophy**

Flux is a high-performance, multi-paradigm systems programming language designed as the native interface for StratOS. It is built on a core belief that the language a system uses should be as capable as the system itself: able to touch bare hardware when needed, yet expressive enough for rapid application development.

Flux draws inspiration from C++ (performance, control), Swift (clean syntax, ARC memory model), and Python (readability, shell-style scripting). The result is a language that feels familiar to any programmer but breaks new ground in several key areas.

## **1.1 Core Philosophy Pillars**

**Hardware Sovereign.** When running on StratOS, Flux treats itself as the top-level interface. It provides direct intrinsics for GPU framebuffers, network interface cards, and raw memory without relying on an external OS layer. If you want to write a pixel to the screen, you write a pixel to the screen.

**Fluid Identity.** Data types are static and enforced within any given execution scope, preventing the accidental type coercion bugs common in dynamically-typed languages. However, a variable's type can be explicitly changed across its lifecycle using a deliberate re-declaration syntax. The change is intentional, visible, and tracked by the compiler.

**Visual First.** 32-bit color values, 3D vectors (vec3), and 4x4 matrices (mat4) are primitive-class citizens in Flux, not afterthoughts bolted on through libraries. This is a language designed from the ground up to power graphics.

**Safe by Default.** Flux uses Automatic Reference Counting (ARC) to manage memory automatically in standard code. Unsafe operations are only possible inside an explicitly marked **unsafe { }** block, so dangerous code is always visible and intentional.

## **1.2 Who Is This Manual For?**

This manual is written for two audiences. If you are new to programming or coming from a high-level language, the early chapters provide all the context you need. If you are an experienced systems programmer, you can skip ahead to the chapters covering Flux's unique features: the type system (Chapter 5), the semantic comparators (Chapter 7), and memory management (Chapter 15).

## **1.3 File Extensions**

Flux projects use two file types:

- **.flux** — Executable source files. These contain your main functions, classes, and application logic.
- **.lx** — Library and header files. These define APIs, types, and shared functions for import by other files.

**Note:** C++ files (.cpp, .h) are also accepted by the fluxc compiler for interoperability. See Chapter 17.

  

# **2\. Getting Started**

## **2.1 Your First Flux Program**

Every Flux program begins executing from the main() function. Below is the canonical first program:

\# File: hello.flux

func main() {

print("Hello, World!");

}

To compile and run this program using Ahead-of-Time (AOT) compilation:

\# Compile to a native binary

fluxc build hello.flux -o hello

\# Run the binary

./hello

\# Output:

Hello, World!

Or, run it directly using the JIT interpreter without producing a binary:

flux run hello.flux

\# Output:

Hello, World!

## **2.2 A More Complete Example**

Here is a small but complete program that demonstrates variables, functions, a loop, and basic I/O. Each concept shown here is explained in full in the chapters that follow.

\# File: greet.flux

\# A function that builds a greeting string

func greet(string name, int times) -> string {

string result = "";

for (int i = 0; i < times; i++) {

result += "Hello, $name!\\n";

}

return result;

}

func main() {

string user = input("Enter your name: ");

string message = greet(user, 3);

print(message);

}

Running this program will prompt the user for their name and then print a personalized greeting three times. The $ character inside a string is used for variable interpolation, which is covered in Chapter 4.

## **2.3 Program Structure Overview**

A typical Flux source file is structured as follows. There are no mandatory ordering rules, but this is the conventional layout used throughout this manual:

\# 1. Imports

import std.net;

import "my_library.lx";

\# 2. Constants

int MAX_PLAYERS = 8;

\# 3. Structs and Class Definitions

struct Vec2 { float x; float y; }

\# 4. Helper Functions

func helper(int val) -> int { return val \* 2; }

\# 5. Entry Point

func main() {

\# Program logic goes here

}

  

# **3\. The Compiler & Runtime Environment**

Flux uses a dual-stage architecture managed by the fluxc toolchain. Understanding how your code is compiled and executed helps you make the right choices for your project.

## **3.1 Ahead-of-Time (AOT) Compilation**

AOT compilation translates your Flux source code into C++, then compiles that to a native binary using g++. This binary runs directly on the CPU with no interpreter overhead, making it the right choice for production builds and performance-critical applications.

The transpiler generates a self-contained C++ file with a lightweight runtime layer. Flux types map directly to C++ types: `int` → `int32_t`, `float` → `double`, `string` → `std::string`, `bool` → `bool`. Lists become `std::vector<T>` with the element type inferred from the declared Flux type. User-defined classes become C++ structs with member functions, and class inheritance uses C++ struct inheritance. Enums emit as namespaces with `static const int32_t` members.

The AOT compiler supports the full Flux feature set including:

- Functions, lambdas, and immediately-invoked function expressions (IIFEs)
- Classes with fields, methods, constructors (`init`), and multi-level inheritance (`super.init()`)
- Enum declarations and member access
- Lists with `.add()`, `.removeAt()`, `.sort()`, `.length`, and index access
- String interpolation (`$var` and `${expr}`)
- Cast expressions (`(int) x`, `(string) y`, including string-to-int conversion)
- Control flow: `if`/`elif`/`else`, `for`, `for-each`, `while`, `do-while`, `switch`
- Error handling: `try`/`catch`/`throw`
- Built-in functions: `print`, `print_raw`, `len`, `typeof`, `math.sqrt`, `math.PI`, etc.

**AOT behavioral notes:** Runtime const enforcement (UPPER_SNAKE_CASE variables) is not replicated in AOT mode — assignments to const-named variables succeed silently rather than throwing a catchable error. Standard library types (`Window`, `Timer`, `Socket`, `Map`, `Stack`, `Queue`) and user-defined classes are passed by reference in AOT mode to match Flux's reference-type object semantics. Functions without a return type annotation are emitted as returning `int32_t` with an implicit `return 0` at the end.

```
# Basic compile (defaults to -O2)
flux compile main.flux -o my_app

# Fast compile — no optimization, quickest build time
flux compile main.flux --fast -o my_app_debug

# Release — maximum optimization (-O3)
flux compile main.flux --release -o my_app_release

# Size — smallest binary (-Os)
flux compile main.flux --size -o bootloader

# Dev mode — saves the intermediate .gen.cpp file alongside the binary
flux compile main.flux --dev -o my_app
```

|     |     |     |
| --- | --- | --- |
| **Flag** | **Meaning** | **Use When** |
| --fast | No optimization (-O0). Fastest compile time. | Development & debugging |
| (default) | Balanced optimization (-O2). | General use |
| --release | Aggressive optimization (-O3): inlining, loop unrolling, vectorization. | Production releases |
| --size | Minimize binary size (-Os). | Embedded, bootloaders |
| --dev | Saves the generated `.gen.cpp` file next to the output binary. | Debugging transpiler output |

## **3.2 Just-in-Time (JIT) Execution**

The JIT mode compiles source code to an Intermediate Representation (IR) in memory and executes it immediately. There is no output binary. This mode is ideal for rapid iteration, interactive scripting, and hot-reloading during development.

\# Run a script directly

flux run script.flux

\# Launch the interactive Flux shell

flux

\# Inside the interactive shell:

\> int x = 42;

\> print(x \* 2);

84

\>

### **Hot-Reloading**

When running in JIT development mode, the Flux runtime monitors your source files for changes. When a .flux file is saved, the JIT engine can hot-swap the function pointers at runtime without restarting the process. This is particularly powerful for game development, where you can tweak game logic while the game is running.

\# Launch in development mode with hot-reload enabled

flux run --dev game.flux

\# Now edit any .flux file in your project.

\# Changed functions will be live-updated automatically.

## **3.3 The exec() Function**

Flux provides a built-in function that allows you to compile and execute a string of Flux code at runtime using the JIT engine. This is a powerful but security-sensitive feature.

\# Signature

func exec(string code, string mode = "full") -> void

\# Example: dynamic code execution

string code = "print(\\"Executed at runtime!\\");";

exec(code);

### **Sandbox Mode**

Because exec() runs arbitrary code, it supports a sandbox mode that restricts what the executed code is allowed to do. This is critical for any application that runs user-provided code.

\# Mode "full" (default) - full kernel privileges.

\# DANGEROUS with untrusted input!

exec(userInput);

\# Mode "sandbox" - restricted execution environment.

\# - No file system access

\# - No network access

\# - Maximum 512MB RAM

\# - No unsafe{} blocks allowed

exec(userInput, mode: "sandbox");

**Warning:** Never use exec() in "full" mode with user-provided input. Always use "sandbox" mode when executing untrusted code.

## **3.4 Module System (Imports & Exports)**

Flux uses an explicit module system. You must import a file or library before you can use anything it provides.

### **Importing**

\# Import a local library file

import "libs/graphics.lx";

\# Import from the standard library

import std.net;

import std.math;

import std.collections;

\# Import a C++ header (C++ bridge)

import "legacy_driver.cpp";

### **Exporting**

To make a function, class, or variable available to other files that import yours, use the export keyword.

\# In my_library.lx

\# This function is public and importable

export func calculateDistance(float x1, float y1, float x2, float y2) -> float {

return \`\\sqrt{(x2 - x1)^2 + (y2 - y1)^2}\`;

}

\# This function is private to this file

func internalHelper(int v) -> int {

return v \* 2;

}

  

# **4\. Lexical Structure & Syntax**

This chapter covers the low-level rules of how Flux source code is written — the "letters and words" of the language.

## **4.1 Comments**

Flux supports three styles of comments. Comments are ignored by the compiler.

\# This is a single-line comment (shell style)

// This is also a single-line comment (C style)

/\*

This is a multi-line block comment.

It can span as many lines as needed.

\*/

int x = 10; # Inline comment after code

## **4.2 Identifiers & Naming Conventions**

An identifier is any name you give to a variable, function, or class. Identifiers are case-sensitive, must begin with a letter or underscore, and can contain letters, digits, and underscores.

\# Valid identifiers

myVariable

\_privateValue

player1Score

MAX_BUFFER_SIZE

\# Invalid identifiers

1stPlayer # Cannot start with a digit

my-variable # Hyphens not allowed

class # Reserved keyword

Flux enforces the following naming conventions by strong community standard:

|     |     |     |
| --- | --- | --- |
| **Style** | **Used For** | **Example** |
| camelCase | Variables, functions | playerHealth, calculateForce() |
| PascalCase | Classes, structs, interfaces | RigidBody, HttpClient |
| UPPER_SNAKE_CASE | Constants | MAX_BUFFER_SIZE, PI |

## **4.3 String Interpolation**

Flux supports embedding variable values directly inside strings using the $ character. This avoids clumsy concatenation and is the preferred way to build strings dynamically.

int hp = 100;

string name = "Aria";

\# Simple variable: $varName

print("Player: $name");

\# Output: Player: Aria

\# Expression in braces: ${expression}

print("Half HP: ${hp / 2}");

\# Output: Half HP: 50

\# Complex expression

print("Status: $name has ${hp \* 0.75} shield points remaining.");

\# Output: Status: Aria has 75.0 shield points remaining.

**Note:** To print a literal dollar sign, escape it with a backslash: \\$

## **4.4 String Methods**

Strings in Flux have built-in methods for common text manipulation. These work in both JIT and AOT modes.

| Method | Signature | Description |
| --- | --- | --- |
| length | `.length` (property) | Returns the number of characters in the string. |
| substring | `.substring(start, length)` | Returns a portion of the string starting at `start` with the given `length`. |
| indexOf | `.indexOf(search)` | Returns the index of the first occurrence of `search`, or `-1` if not found. |
| contains | `.contains(search)` | Returns `true` if the string contains `search`. |
| startsWith | `.startsWith(prefix)` | Returns `true` if the string starts with `prefix`. |
| endsWith | `.endsWith(suffix)` | Returns `true` if the string ends with `suffix`. |
| split | `.split(delimiter)` | Splits the string by `delimiter` and returns a `list` of strings. |
| trim | `.trim()` | Removes leading and trailing whitespace. |
| toUpper | `.toUpper()` | Returns the string converted to uppercase. |
| toLower | `.toLower()` | Returns the string converted to lowercase. |
| replace | `.replace(old, new)` | Replaces all occurrences of `old` with `new`. |
| charAt | `.charAt(index)` | Returns the character at the given index as a single-character string. |
| reverse | `.reverse()` | Returns the string with characters in reverse order. |

```flux
string name = "Hello, World!";
print(name.length);            # 13
print(name.substring(7, 5));   # World
print(name.indexOf("World"));  # 7
print(name.contains("Hello")); # true
print(name.toUpper());         # HELLO, WORLD!

string csv = "a,b,c";
list parts = csv.split(",");   # ["a", "b", "c"]

string padded = "  hi  ";
print(padded.trim());          # hi
```

## **4.5 Reserved Keywords**

The following words are reserved by Flux and cannot be used as identifiers:

|     |     |     |     |
| --- | --- | --- | --- |
| **Keywords A–D** | **Keywords E–I** | **Keywords N–S** | **Keywords T–W** |
| atomic | else | new | thread |
| bool | elif | null | true |
| break | enum | panic | try |
| butnot | exec | private | unsafe |
| byte | export | public | void |
| catch | extends | return | while |
| char | false | struct |     |
| class | for | switch |     |
| cleanup | func | implements |     |
| continue | if  | interface |     |
| do  | import | int |     |

## **4.6 Literals**

A literal is a fixed value written directly in your code.

\# Integer literals

int a = 42;

int b = -7;

int hex = 0xFF; # Hexadecimal (255)

int bin = 0b1010; # Binary (10)

\# Floating-point literals

float pi = 3.14159;

float sci = 1.5e10; # Scientific notation

\# Boolean literals

bool isActive = true;

bool isDead = false;

\# String literals

string greeting = "Hello, World!";

string escaped = "Tab:\\t Newline:\\n";

\# Character literal

char grade = 'A';

\# Null literal

void result = null;

  

# **5\. The Type System**

Flux uses Mutable Static Typing (also called Scope-Locked Mutability). This is one of Flux's most distinctive features and is worth understanding thoroughly.

## **5.1 The Core Rule**

A variable's type is fixed and enforced within any single execution scope. You cannot assign a value of the wrong type to a variable — the compiler will stop you. However, you can explicitly re-declare a variable with a new type using a specific syntax. The old memory is freed, and a new variable of the new type is created. If the variable type changes, but the new type cannot process it, such as `string` becoming a `char`, the value of that variable becomes `null`.

## **5.2 Primitive Types**

Flux provides the following built-in primitive types:

|     |     |     |     |
| --- | --- | --- | --- |
| **Keyword** | **Size** | **Range / Description** | **Example** |
| void | 0 bits | Represents no value / null | void result = null; |
| bool | 1 byte | true or false | bool isAlive = true; |
| char | 1 byte | Single ASCII character (0–127) | char grade = 'A'; |
| byte | 1 byte | Unsigned integer (0–255) | byte flags = 0xFF; |
| int | 4 bytes | Signed 32-bit (-2B to +2B) | int score = 1000; |
| long | 8 bytes | Signed 64-bit integer | long timestamp = 9999999; |
| float | 8 bytes | IEEE 754 double precision | float speed = 9.81; |
| string | Dynamic | UTF-8 text sequence | string name = "Flux"; |
| list | Dynamic | Ordered collection of values | list items = [1, 2, 3]; |
| object | Dynamic | Dynamic key-value container (returned by JSON.parse) | object data = JSON.parse(str); |

### **Visual & Graphics Primitives**

Because Flux is designed for graphics programming, the following types are also primitives (not library types). They are covered in depth in Chapter 16.

|     |     |     |
| --- | --- | --- |
| **Type** | **Description** | **Example** |
| vec2 | 2D vector (x, y) | vec2 pos = vec2(100, 200); |
| vec3 | 3D vector (x, y, z) | vec3 origin = vec3(0, 0, 0); |
| mat4 | 4x4 float matrix | mat4 proj = mat4.identity(); |
| color32 | 32-bit RGBA color value | color32 red = 0xFF0000FF; |

## **5.3 Type Re-Definition (The "Flux" Behavior)**

This is the behavior the language is named for. A variable can flow from one type to another across its lifecycle. To change a variable's type, you use the explicit re-declaration syntax:

\# Standard assignment (type must match)

int count = 100;

count = 200; # OK - still int

count = "two hundred"; # COMPILER ERROR - type mismatch

\# Type re-declaration syntax: identifier = new_type = value

count = string = "two hundred"; # OK - explicit re-type

\# The int memory is freed. count is now a string.

print(count); # Prints: two hundred

### **Scope-Locking Rule**

Type re-definition creates a local shadow. If you re-type a global variable from inside a function, the global is unchanged. Only the local scope is affected.

int globalScore = 9999;

func displayScore() {

\# Re-type creates a LOCAL shadow of globalScore.

globalScore = string = "9999"; # another way of writing this would be globalScore = string;, Since the compiler is automatically capable of changing the type of the variable, while keeping the information constant

print(globalScore); # Prints: 9999 (local string)

}

func main() {

displayScore();

print(globalScore); # Prints: 9999 (global int is untouched)

}

**Note:** The destructor of the old value is called immediately when a re-type occurs. Memory is reclaimed at that exact moment, not later.

## **5.4 Enums**

Enums define a named set of constant integer values. They are ideal for representing a fixed set of states, options, or codes. Enums are always referenced by their type name.

enum Direction {

NORTH, # = 0

SOUTH, # = 1

EAST, # = 2

WEST # = 3

}

\# Explicit values

enum HttpStatus {

OK = 200,

NOT_FOUND = 404,

ERROR = 500

}

Direction heading = Direction.NORTH;

if (heading == Direction.NORTH) {

print("Heading north!");

}

  

# **6\. Variables & Constants**

## **6.1 Variable Declaration**

All variables must be declared with a type. Flux does not infer types on first assignment. This makes code easier to read and helps the compiler produce better error messages.

\# Syntax: type name = value;

int playerScore = 0;

float gravity = 9.81;

string playerName = "Atlas";

bool isGameOver = false;

\# Variables can be declared without a value (they are zero-initialized)

int counter; # counter = 0

float temperature; # temperature = 0.0

string buffer; # buffer = ""

bool flag; # flag = false

## **6.2 Constants**

A constant is a variable whose value cannot change after it is first assigned. Use constants for values that are fixed for the life of the program, such as configuration values, mathematical constants, or buffer sizes.

\# Constants use the same declaration syntax but are named UPPER_SNAKE_CASE

\# by convention. The compiler enforces immutability.

int MAX_PLAYERS = 16;

float PI = 3.14159265358979;

string APP_VERSION = "0.1.0";

\# Attempting to reassign a constant is a compile error:

MAX_PLAYERS = 32; # COMPILER ERROR: Cannot reassign constant MAX_PLAYERS

**Note:** The compiler determines something is a constant when its name follows UPPER_SNAKE_CASE convention and it is declared at the global scope. You can explicitly mark a variable constant with the const keyword as well.

## **6.3 Null and the void Type**

void represents the absence of a value. A variable of type void can only hold null. This is used for optional values and for functions that do not return a result.

void result = null;

\# Check for null before using

if (result == null) {

print("No value present");

}

\# A function that returns nothing

func logMessage(string msg) -> void {

print(msg);

\# no return statement needed

}

## **6.4 Type Conversion**

Flux does not perform implicit type conversion. You must explicitly cast when converting between types. This prevents subtle bugs where values are silently mangled.

float score = 98.6;

\# Explicit cast: (target_type) value

int roundedScore = (int) score; # roundedScore = 98 (truncated)

string scoreText = (string) score; # scoreText = "98.6"

\# Casting a string to a number (will panic if string is not a valid number)

string input = "42";

int parsed = (int) input; # parsed = 42

\# Safe cast: returns null instead of panicking on failure

int? safeValue = (int?) input;

if (safeValue != null) {

print(safeValue);

}

  

# **7\. Operators & Logic**

Operators are symbols that perform operations on values. Flux includes all standard operators plus several unique ones that make common programming tasks more expressive.

## **7.1 Arithmetic Operators**

|     |     |     |
| --- | --- | --- |
| **Operator** | **Name** | **Example** |
| +   | Addition | int sum = 5 + 3; // 8 |
| \-  | Subtraction | int diff = 10 - 4; // 6 |
| \*  | Multiplication | float area = 3.0 \* 4.0; // 12.0 |
| /   | Division | float half = 10 / 4.0; // 2.5 |
| %   | Modulo (remainder) | int rem = 10 % 3; // 1 |
| ++  | Increment (add 1) | count++; // same as count = count + 1 |
| \-- | Decrement (subtract 1) | lives--; // same as lives = lives - 1 |

## **7.2 Assignment Operators**

int x = 10;

x += 5; # x = x + 5 --> 15

x -= 3; # x = x - 3 --> 12

x \*= 2; # x = x \* 2 --> 24

x /= 4; # x = x / 4 --> 6

x %= 4; # x = x % 4 --> 2

## **7.3 Comparison Operators**

|     |     |     |
| --- | --- | --- |
| **Operator** | **Meaning** | **Example** |
| \== | Equal to (identity) | 5 == 5 // true |
| !=  | Not equal to | 5 != 6 // true |
| <   | Less than | 3 < 5 // true |
| \>  | Greater than | 5 > 3 // true |
| <=  | Less than or equal to | 5 <= 5 // true |
| \>= | Greater than or equal to | 10 >= 9 // true |

## **7.4 Logical Operators**

bool a = true;

bool b = false;

a && b # AND: true only if BOTH are true --> false

a || b # OR: true if at LEAST ONE is true --> true

!a # NOT: flips the value --> false

## **7.5 The Exclusionary Operator: butnot**

butnot is a semantic operator unique to Flux. It is equivalent to && ! (AND NOT), but reads more naturally, especially when working with permission logic or filtering.

\# butnot: true when A is true AND B is false

\# Equivalent to: A && !B

bool isAdmin = true;

bool isBanned = false;

if (isAdmin butnot isBanned) {

print("Access granted.");

}

\# Truth table for A butnot B:

\# A=true, B=true --> false (Admin, but is also banned)

\# A=true, B=false --> true (Admin and NOT banned)

\# A=false, B=true --> false (Not admin)

\# A=false, B=false --> false (Not admin)

## **7.6 Semantic Comparators**

Standard equality (==) in many languages has hidden type-coercion rules that cause bugs. Flux solves this with three distinct equality operators, each with a clear, documented contract.

### **\== (Identity Equality)**

Compares values logically, allowing cross-type comparisons when the value is representable in both types. Use this for general equality checks.

string s = "10";

int i = 10;

bool b = true;

print(s == i); # true ("10" and 10 have the same value)

print(1 == b); # true (1 and true are identity-equal)

print("A" == "A"); # true

### **\=num= (Numeric Strict Equality)**

Returns true ONLY if both operands are valid numeric types (int, long, float, byte) and their values match. Strings that look like numbers do NOT pass this check.

print("50" =num= 50); # false - string vs int

print(50.0 =num= 50); # true - float vs int (both numeric)

print(50L =num= 50); # true - long vs int (both numeric)

print(true =num= 1); # false - bool is not numeric in =num= context

### **\=word= (String Strict Equality)**

Returns true ONLY if both operands are string types and their content matches exactly, including case.

print("hello" =word= "hello"); # true

print("Hello" =word= "hello"); # false - case sensitive

print("50" =word= 50); # false - int is not a string

print("50" =word= "50"); # true

**Note:** Use == for everyday comparisons. Use =num= when you need to guarantee you are comparing real numbers (e.g., financial calculations, physics). Use =word= when you need to guarantee you are comparing text (e.g., password checks, command parsing).

## **7.7 Operator Precedence**

When multiple operators appear in a single expression, Flux evaluates them in a fixed order. Higher rows in this table are evaluated first. Use parentheses to override this order.

|     |     |     |
| --- | --- | --- |
| **Level** | **Operators** | **Description** |
| 1 (highest) | . \[\] () | Accessors, subscript, call |
| 2   | ! - ++ -- .random | Unary operators |
| 3   | \* / % | Multiplicative |
| 4   | \+ - | Additive |
| 5   | &lt; &gt; &lt;= &gt;= | Relational |
| 6   | \=num= =word= == != | Equality / Semantic |
| 7   | && \| butnot | Logical |
| 8 (lowest) | \= += -= \*= /= new_type= | Assignment |

  

# **8\. Control Flow**

Control flow statements change the order in which code executes — they allow you to make decisions, repeat actions, and skip code based on conditions.

## **8.1 If / elif / else**

The if statement executes a block of code only if its condition is true. Use elif (else if) to check additional conditions. Use else as a fallback.

int score = 75;

if (score >= 90) {

print("Grade: A");

} elif (score >= 80) {

print("Grade: B");

} elif (score >= 70) {

print("Grade: C");

} else if (score >= 60) {

print("Grade: D"); # else if also works

} else {

print("Grade: F");

}

**Note:** Both elif and else if are valid syntax in Flux. They are identical in behavior. elif is preferred by convention for consistency.

## **8.2 Switch Statements**

A switch statement is a cleaner alternative to a long chain of if/elif when you are testing a single variable against multiple fixed values.

int statusCode = 404;

switch (statusCode) {

case 200:

print("200 OK - Success");

break;

case 301:

print("301 Moved Permanently");

break;

case 404:

print("404 Not Found");

break;

case 500:

print("500 Internal Server Error");

break;

default:

print("Unknown status code: $statusCode");

}

**Warning:** Every case block must end with break; unless you intentionally want fall-through behavior. Without break, execution continues into the next case.

### **Switching on Strings and Enums**

\# Switch works on strings

string command = "jump";

switch (command) {

case "jump":

player.jump();

break;

case "attack":

player.attack();

break;

default:

print("Unknown command");

}

\# Switch works on enums

Direction dir = Direction.NORTH;

switch (dir) {

case Direction.NORTH: moveUp(); break;

case Direction.SOUTH: moveDown(); break;

case Direction.EAST: moveRight(); break;

case Direction.WEST: moveLeft(); break;

}

## **8.3 For Loop**

The for loop repeats a block of code a controlled number of times. It has three parts: an initializer, a condition, and an update expression.

\# Standard for loop: count from 0 to 9

for (int i = 0; i < 10; i++) {

print(i);

}

\# Counting downward

for (int i = 10; i > 0; i--) {

print(i);

}

\# Iterating over a list

List&lt;string&gt; names = \["Alice", "Bob", "Carol"\];

for (int i = 0; i < names.length; i++) {

print("Hello, ${names\[i\]}!");

}

\# For-each style iteration

for (string name in names) {

print("Hello, $name!");

}

## **8.4 While Loop**

The while loop repeats as long as a condition is true. It checks the condition BEFORE executing the body, so if the condition starts as false, the body never runs.

int lives = 3;

while (lives > 0) {

print("Playing... lives left: $lives");

lives = lives - playRound(); # playRound() returns lives lost

}

print("Game Over!");

## **8.5 Do-While Loop**

The do-while loop is similar to while, but it checks the condition AFTER executing the body. This guarantees the body runs at least once.

bool connectionFailed = true;

int attempts = 0;

do {

attempts++;

print("Connection attempt #$attempts...");

connectionFailed = tryConnect();

} while (connectionFailed && attempts < 5);

if (connectionFailed) {

print("Could not connect after 5 attempts.");

} else {

print("Connected!");

}

## **8.6 Loop Control: break and continue**

Inside any loop, two keywords give you fine-grained control over execution flow:

\# break: exit the loop immediately

for (int i = 0; i < 100; i++) {

if (i == 50) {

print("Stopping at 50.");

break; # Loop ends here. i will be 50.

}

print(i);

}

\# continue: skip the rest of this iteration and go to the next

for (int i = 0; i < 10; i++) {

if (i % 2 == 0) {

continue; # Skip even numbers

}

print(i); # Only prints 1, 3, 5, 7, 9

}

  

# **9\. Functions, Methods & Closures**

Functions are named, reusable blocks of code. They are the primary way to organize and structure your programs in Flux.

## **9.1 Declaring Functions**

Functions are declared with the func keyword. The return type is specified after a -> arrow. If the return type is omitted, it defaults to int and returns 0 automatically.

\# Function with return type annotation

func add(int a, int b) -> int {

return a + b;

}

\# Function with no return value

func logError(string message) -> void {

print("\[ERROR\] $message");

}

\# Function with no return type annotation

\# (defaults to int, auto-returns 0)

func initialize() {

setupDisplay();

loadAssets();

\# implicitly returns 0 here

}

## **9.2 Calling Functions**

int sum = add(3, 7); # sum = 10

logError("File not found");

int status = initialize(); # status = 0

## **9.3 Named Arguments**

Flux supports named arguments, which allow you to pass arguments in any order and make your call sites more readable. Especially useful when a function has many parameters.

func createWindow(int width, int height, string title, bool fullscreen) {

\# ...

}

\# Positional call (must be in order)

createWindow(1920, 1080, "My App", false);

\# Named call (any order)

createWindow(title: "My App", fullscreen: false, width: 1920, height: 1080);

\# Mix of positional and named

createWindow(1920, 1080, title: "My App", fullscreen: true);

## **9.4 Default Parameter Values**

Parameters can have default values, making them optional in function calls.

func connect(string host, int port = 80, bool secure = false) -> bool {

\# ...

}

\# Using defaults

connect("google.com"); # port=80, secure=false

connect("google.com", 443, true); # All specified

connect("google.com", secure: true); # port=80 (default), secure=true

## **9.5 Access Modifiers on Functions**

Functions inside classes and exported from modules can have access modifiers. At the file level, functions are private by default.

public func visibleToEveryone() { ... }

private func onlyInsideThisFile() { ... }

## **9.6 Generics**

Generic functions can operate on any type. The type parameter is declared inside angle brackets &lt; &gt; before the argument list.

\# A generic function that works with any type T

func printItem&lt;T&gt;(T item) -> void {

print(item);

}

printItem&lt;int&gt;(42);

printItem&lt;string&gt;("Hello");

printItem&lt;float&gt;(3.14);

\# Generic function returning T

func getFirst&lt;T&gt;(List&lt;T&gt; list) -> T {

return list\[0\];

}

## **9.7 Anonymous Functions (Lambdas)**

Lambdas are functions without names. They are useful as short, inline callbacks — for sorting, event handling, or any case where you need to pass behavior as a value.

\# Lambda syntax: (params) => { body }

\# or for single expressions: (params) => expression

\# Sort a list of integers ascending

List&lt;int&gt; scores = \[88, 42, 95, 71, 56\];

scores.sort( (a, b) => { return a < b; } );

\# scores is now \[42, 56, 71, 88, 95\]

\# Short form (single expression)

scores.sort( (a, b) => a < b );

\# Store a lambda in a variable

func&lt;int, int, int&gt; multiply = (int x, int y) => x \* y;

int result = multiply(6, 7); # result = 42

## **9.8 Recursive Functions**

\# Functions can call themselves (recursion)

func factorial(int n) -> int {

if (n <= 1) return 1;

return n \* factorial(n - 1);

}

print(factorial(5)); # 120

  

# **10\. Object-Oriented Programming**

Flux is a multi-paradigm language with full support for Object-Oriented Programming (OOP). OOP helps you model real-world concepts by grouping related data and behavior into units called objects.

## **10.1 Classes & Objects**

A class is a blueprint. An object is a specific instance created from that blueprint. You create an object with the new keyword.

class Player {

\# Properties (data the player holds)

public string gamertag;

public int level;

private int score; # private: only accessible inside this class

private int health;

\# Constructor: called when 'new Player(...)' is used

func init(string name) {

gamertag = name;

level = 1;

score = 0;

health = 100;

}

\# Public method

public func addScore(int points) -> void {

score += points;

}

\# Getter for private property

public func getScore() -> int {

return score;

}

public func takeDamage(int dmg) -> void {

health -= dmg;

if (health < 0) health = 0;

}

public func isAlive() -> bool {

return health > 0;

}

}

\# Creating and using an object

Player hero = new Player("Atlas");

hero.addScore(500);

print("${hero.gamertag} has ${hero.getScore()} points.");

## **10.2 Inheritance**

A child class can extend a parent class, inheriting all its public and protected properties and methods. Use `extends` to declare inheritance. Flux supports single inheritance, including multi-level inheritance chains (e.g., `Child extends Middle extends Base`).

Within a method body, other methods on the same object (including inherited methods) can be called by name directly, without needing to qualify them through the object reference. Fields are also accessible by name.

```
class Base {
    public string tag;
    func init() { tag = "base"; }
    public func identify() -> string { return "I am $tag"; }
}

class Child extends Base {
    func init() { super.init(); tag = "child"; }
    public func info() -> string {
        return identify();  # Calls inherited method by name
    }
}
```

\# Parent class

class Character {

public string name;

protected int hp; # protected: accessible in this class AND subclasses

func init(string n, int startHp) {

name = n;

hp = startHp;

}

public func speak() -> void {

print("$name says hello.");

}

}

\# Child class inherits from Character

class Warrior extends Character {

private int armor;

func init(string n) {

super.init(n, 200); # Call parent constructor

armor = 50;

}

\# Override the parent method

public func speak() -> void {

print("$name roars: FOR GLORY!");

}

public func block() -> int {

return armor;

}

}

Warrior w = new Warrior("Thor");

w.speak(); # Prints: Thor roars: FOR GLORY!

## **10.3 Interfaces**

An interface defines a contract: a set of methods that a class must implement. Interfaces cannot have any implementation themselves — they only declare what methods must exist. Use implements to apply an interface to a class.

\# Define an interface

interface Serializable {

func toJson() -> string;

func toBytes() -> byte\[\];

}

interface Printable {

func print() -> void;

}

\# Implement multiple interfaces

class SaveState implements Serializable, Printable {

int level;

int score;

func init(int l, int s) { level = l; score = s; }

\# Must implement ALL methods from Serializable

public func toJson() -> string {

return "{\\"level\\": $level, \\"score\\": $score}";

}

public func toBytes() -> byte\[\] {

\# ... implementation

}

\# Must implement ALL methods from Printable

public func print() -> void {

print("Level $level | Score $score");

}

}

## **10.4 Structs**

Structs are lightweight data containers. Unlike classes, structs are passed by value (a copy is made when passed to a function), not by reference. They do not support inheritance or interfaces. Use structs for simple data groups like coordinates, colors, or sizes.

struct Vector3 {

float x;

float y;

float z;

}

struct Rect {

int x;

int y;

int width;

int height;

}

\# Creating a struct (no 'new' keyword needed)

Vector3 velocity = { x: 0.0, y: -9.81, z: 0.0 };

Rect viewport = { x: 0, y: 0, width: 1920, height: 1080 };

\# Accessing fields

velocity.y = -5.0;

print("Velocity Y: ${velocity.y}");

|     |     |     |
| --- | --- | --- |
| **Feature** | **Class** | **Struct** |
|     |     |
| Passed by | Reference | Value (copy) |
| Inheritance | Yes (extends) | No  |
| Interfaces | Yes (implements) | No  |
| Constructor | Yes (func init) | No (field initializer) |
| Best for | Complex entities with behavior | Simple data containers |

  

# **11\. Error Handling & Safety**

Robust software must handle failure gracefully. Flux provides two complementary mechanisms: Exceptions (for recoverable errors) and Panics (for unrecoverable, fatal errors).

## **11.1 Try / Catch (Recoverable Errors)**

Use try/catch when a block of code might fail in ways you can handle — file not found, network timeout, invalid user input. The program continues running after a caught exception.

try {

\# Code that might fail

string content = fs.read("/config/settings.json");

HttpClient c = new HttpClient();

Response r = c.get("https://api.example.com/data");

} catch (FileSystemError e) {

\# Handle a specific error type

print("Could not read config: $e.message");

loadDefaultConfig(); # Fall back gracefully

} catch (NetworkError e) {

print("Network request failed: $e.message (code: $e.code)");

} catch (error e) {

\# Catch-all for any other error type

print("Unexpected error: $e");

} finally {

\# This block ALWAYS runs, whether or not an exception occurred

print("Cleanup complete.");

}

### **Error Object Properties**

All error objects have these standard properties:

- **e.message** — A human-readable description of the error.
- **e.code** — An integer error code (for network and system errors).
- **e.stack** — A string containing the call stack at the point of failure.

### **Custom Errors**

class GameError extends error {

string context;

func init(string msg, string ctx) {

super.message = msg;

context = ctx;

}

}

\# Throw a custom error

func loadLevel(int id) {

if (id < 0) {

throw new GameError("Invalid level ID", "loadLevel()");

}

\# ... load the level

}

## **11.2 panic (Unrecoverable Errors)**

panic is for situations where the program cannot safely continue. It is not caught by try/catch. When panic is called, the current thread halts immediately and an error message is printed. If called in kernel mode, the entire OS halts.

\# Use panic for situations that should NEVER happen in correct code

func allocateBuffer(int size) -> byte\[\] {

if (size <= 0) {

panic("allocateBuffer called with size <= 0. This is a programmer error.");

}

\# ...

}

\# Kernel-level panic (halts the OS)

if (memoryCorruption == true) {

panic("KERNEL FAULT: Memory corruption detected at 0xDEADBEEF. System halted.");

}

**Warning:** panic is a last resort, not a normal error handling tool. If a situation is recoverable at all, use try/catch instead.

## **11.3 Error Types Reference**

|     |     |
| --- | --- |
| **Error Type** | **Thrown When** |
| FileSystemError | File not found, permission denied, disk full |
| NetworkError | Connection refused, timeout, DNS failure |
| ParseError | Invalid JSON, malformed data, bad cast |
| MemoryError | Allocation failure, out-of-memory |
| TypeError | Type mismatch at runtime (rare in Flux) |
| IndexError | Array/list access out of bounds |
| error | Base type — catches any error not listed above |

  

# **12\. Concurrency**

Modern applications need to do multiple things at once — loading data, processing input, and rendering a frame simultaneously. Flux provides first-class support for concurrency through OS-level threads.

## **12.1 Threads**

A thread is an independent path of execution. Flux threads map 1:1 to OS threads, giving you direct control over the CPU.

import std.sys;

func downloadFile(string url) {

print("Downloading: $url");

\# ... network code

print("Done: $url");

}

func main() {

\# Launch a function in a new thread

thread t1 = thread.run(downloadFile, "https://example.com/file1.zip");

thread t2 = thread.run(downloadFile, "https://example.com/file2.zip");

\# Both downloads happen simultaneously.

\# Wait for both to finish before continuing.

t1.join();

t2.join();

print("All downloads complete.");

}

## **12.2 Mutex (Mutual Exclusion)**

When multiple threads access the same data, you can get race conditions — two threads reading and writing the same variable at the same time. A mutex (lock) ensures only one thread can access a protected section at a time.

import std.sys;

int sharedCounter = 0;

mutex counterLock;

func increment() {

for (int i = 0; i < 1000; i++) {

counterLock.lock();

sharedCounter++; # Protected section

counterLock.unlock();

}

}

func main() {

thread t1 = thread.run(increment);

thread t2 = thread.run(increment);

t1.join();

t2.join();

print(sharedCounter); # Always 2000, never a random value

}

## **12.3 Atomic Variables**

For simple integer counters and flags, atomic variables provide thread-safe operations without the overhead of a full mutex. An atomic variable's reads and writes are guaranteed to be indivisible — they can never be interrupted mid-operation.

\# Declare an atomic integer

atomic int requestCount = 0;

func handleRequest() {

requestCount++; # Thread-safe increment, no lock needed

\# ...process request

}

\# Atomic bool for flags

atomic bool isShuttingDown = false;

func workerLoop() {

while (isShuttingDown butnot false) {

doWork();

}

}

**Note:** Use atomic for simple counters and boolean flags. Use mutex for anything more complex — protecting multiple lines of code or complex data structures.

  

# **13\. Networking & I/O**

Flux includes a full networking stack in std.net and filesystem and console I/O in std.io.

## **13.1 Standard I/O**

import std.io;

\# Print to stdout

print("Hello, World!");

\# Print without newline

print_raw("Enter value: ");

\# Read a line from stdin

string name = input("What is your name? ");

print("Hello, $name!");

\# Read a number from stdin

int age = (int) input("Enter your age: ");

## **13.2 File System**

import std.io;

\# Read a file as a string

try {

string contents = fs.read("/home/user/notes.txt");

print(contents);

} catch (FileSystemError e) {

print(e.message);

}

\# Write a string to a file (overwrites if exists)

fs.write("/tmp/output.txt", "Hello from Flux!\\n");

\# Append to a file

fs.append("/var/log/app.log", "\[INFO\] Server started.\\n");

\# Check if a file exists

if (fs.exists("/config/settings.json")) {

string config = fs.read("/config/settings.json");

}

\# Delete a file

fs.delete("/tmp/tempfile.bin");

\# List directory contents

List&lt;string&gt; files = fs.list("/home/user/documents/");

for (string file in files) {

print(file);

}

## **13.3 HTTP Client**

import std.net;

func fetchUserData(int userId) -> string {

HttpClient client = new HttpClient();

\# GET request

Response res = client.get("https://api.example.com/users/$userId");

if (res.statusCode =num= 200) {

return res.body;

} else {

throw new NetworkError("API returned: ${res.statusCode}");

}

}

\# POST request with body

func createUser(string json) -> int {

HttpClient client = new HttpClient();

client.setHeader("Content-Type", "application/json");

client.setHeader("Authorization", "Bearer mytoken");

Response res = client.post("https://api.example.com/users", json);

return res.statusCode;

}

## **13.4 TCP Sockets**

For low-level network communication, Flux provides a Socket API with full TCP and UDP support.

import std.net;

\# TCP Client

func connectToServer() {

Socket s = new Socket(Protocol.TCP);

s.connect("192.168.1.100", 8080);

s.write("HELLO SERVER");

string response = s.readLine();

print(response);

s.close();

}

\# TCP Server

func runServer() {

Socket server = new Socket(Protocol.TCP);

server.bind(8080);

server.listen(10); # Max 10 queued connections

print("Server listening on port 8080...");

while (true) {

Socket client = server.accept();

thread t = thread.run(handleClient, client);

}

}

  

# **14\. Mathematics & Physics**

Flux has math deeply integrated into the language itself, not just as a library bolted on after the fact.

## **14.1 The std.math Library**

import std.math;

float a = math.sqrt(144); # 12.0

float b = math.pow(2, 10); # 1024.0

float c = math.abs(-42.5); # 42.5

float d = math.floor(3.9); # 3.0

float e = math.ceil(3.1); # 4.0

float f = math.round(3.5); # 4.0

float g = math.min(5.0, 3.0); # 3.0

float h = math.max(5.0, 3.0); # 5.0

float i = math.clamp(15, 0, 10); # 10.0 (clamp to range \[0,10\])

float j = math.lerp(0, 100, 0.5); # 50.0 (linear interpolation)

\# Trigonometry

float s = math.sin(math.PI / 2); # 1.0

float c2 = math.cos(0.0); # 1.0

float t = math.tan(math.PI / 4); # 1.0

float angle = math.atan2(1, 1); # PI/4

\# Inverse trigonometry

float as = math.asin(1.0); # PI/2

float ac = math.acos(1.0); # 0.0

\# Logarithms and exponentials

float ln = math.log(2.718); # ~1.0 (natural log)

float l2 = math.log2(8.0); # 3.0

float l10 = math.log10(100.0); # 2.0

float ex = math.exp(1.0); # ~2.718 (e^x)

\# Constants

float PI = math.PI; # 3.14159...

float E = math.E; # 2.71828...

float TAU = math.TAU; # 2 \* PI

float INF = math.INF; # Infinity

## **14.2 Intrinsic Randomness**

All primitive types have a built-in .random property that generates a random value of that type, seeded from OS entropy. No setup or seeding required.

\# float.random: generates a float between 0.0 (inclusive) and 1.0 (exclusive)

float roll = float.random;

\# int.random: generates any int in the full signed 32-bit range

int seed = int.random;

\# bool.random: generates true or false with 50/50 probability

bool coinFlip = bool.random;

\# Practical use: random number in a range \[min, max\]

func randomInRange(int min, int max) -> int {

return min + (int)(float.random \* (max - min + 1));

}

int dice = randomInRange(1, 6);

print("Rolled: $dice");

## **14.3 LaTeX Math Engine**

Flux can evaluate mathematical expressions written in LaTeX notation. Wrap a LaTeX expression in backticks and assign it to a float variable. The compiler translates the expression into optimized machine code — there is no string parsing at runtime.

\# Pythagorean theorem

float hyp = \`\\sqrt{a^2 + b^2}\`;

\# Kinematic equation: distance = v_i\*t + (1/2)\*a\*t^2

float d = \`v_i t + \\frac{1}{2} a t^2\`;

\# Quadratic formula

float x = \`\\frac{-b + \\sqrt{b^2 - 4ac}}{2a}\`;

\# Trigonometry

float angle = \`\\sin(x) + \\cos(y)\`;

\# Wave equation

float wave = \`A \\sin(\\omega t + \\phi)\`;

**Note:** Variables in LaTeX expressions refer to Flux variables in the current scope. Ensure the variables used in the LaTeX expression are declared and initialized before the expression is evaluated.

## **14.4 Vectors and Matrices**

vec2, vec3, and mat4 are primitive types in Flux with built-in operations. They use hardware-accelerated SIMD instructions automatically.

\# Vector operations

vec3 a = vec3(1.0, 2.0, 3.0);

vec3 b = vec3(4.0, 5.0, 6.0);

vec3 sum = a + b; # Component-wise addition

vec3 scaled = a \* 2.0; # Scalar multiplication

float dot = a.dot(b); # Dot product

vec3 cross = a.cross(b); # Cross product

float len = a.length(); # Magnitude

vec3 normal = a.normalize(); # Unit vector

\# Matrix operations

mat4 proj = mat4.perspective(60.0, 16.0/9.0, 0.1, 1000.0);

mat4 view = mat4.lookAt(cameraPos, targetPos, upVector);

mat4 mvp = proj \* view; # Matrix multiplication

\# Transform a point

vec3 worldPos = vec3(5, 0, -10);

vec3 screenPos = mvp.transform(worldPos);

  

# **15\. Memory Management & Pointers**

Flux gives you control over memory at multiple levels — from fully automatic management (the default) to raw pointer manipulation (for OS and driver development).

## **15.1 Automatic Reference Counting (ARC)**

By default, you do not manage memory in Flux. The compiler automatically inserts retain and release calls around your variables. When the last reference to a value goes out of scope, its memory is freed immediately.

func processData() {

\# The compiler automatically frees 'data' when processData() returns.

string data = fs.read("/tmp/huge_file.bin");

\# ... use data

} # <-- 'data' is freed here automatically

\# ARC tracks references, not just scope

func main() {

Player p = new Player("Atlas");

Player ref = p; # ARC count: 2 (p and ref both point to the same object)

p.delete; # ARC count: 1 (only ref remains)

} # <-- ref goes out of scope, ARC count: 0, object is freed

## **15.2 Manual Memory Control**

You can take manual control when you know you need to free something immediately (e.g., releasing a large texture before loading the next one).

\# .delete: Force immediate deallocation

\# This calls the destructor and frees all memory NOW.

Texture bigTexture = Texture.load("world_map.png");

\# ... use the texture ...

bigTexture.delete; # Free it NOW before loading the next one

\# cleanup: trigger a garbage collection sweep

\# This cleans up any ARC objects with zero references in the current scope.

func loadLevel(int id) {

\# Load lots of assets...

\# ...

cleanup; # Sweep and free all temporary objects right now

}

## **15.3 Unsafe Blocks & Raw Pointers**

When writing kernel code, device drivers, or working directly with hardware memory maps, you sometimes need to bypass ARC entirely and work with raw memory addresses. This is only possible inside an explicitly marked unsafe { } block.

\# Raw pointer arithmetic is ONLY allowed inside unsafe { }

unsafe {

\# Access the VGA text buffer at memory address 0xB8000

int\* ptr = 0xB8000;

\*ptr = 0x0F41; # Write white 'A' on black background

\# Pointer arithmetic

int\* next = ptr + 1;

\*next = 0x0F42; # Write 'B' in the next position

\# Direct memory allocation (no ARC)

void\* rawMem = mem.alloc(4096); # Allocate 4KB

\# ... use the memory ...

mem.free(rawMem); # Must be freed manually!

}

**Warning:** Code inside unsafe{} bypasses all of Flux's safety guarantees. Memory leaks, buffer overflows, and system crashes are all possible. Only use unsafe{} when absolutely necessary.

## **15.4 Memory Layout & Alignment**

|     |     |     |     |
| --- | --- | --- | --- |
| **Type** | **Size** | **Alignment** | **Notes** |
| bool | 1 byte | 1 byte | Stored as 0 or 1 |
| byte | 1 byte | 1 byte | Unsigned 0–255 |
| char | 1 byte | 1 byte | ASCII value |
| int | 4 bytes | 4 bytes | 32-bit signed |
| long | 8 bytes | 8 bytes | 64-bit signed |
| float | 8 bytes | 8 bytes | IEEE 754 double precision |
| pointer (\*) | 8 bytes | 8 bytes | 64-bit address (ELF-64) |
| vec3 | 24 bytes | 8 bytes | 3x float (SIMD-friendly) |
| mat4 | 128 bytes | 16 bytes | 16x float (16-byte aligned) |

  

# **16\. Graphics & StratOS Internals**

This chapter covers Flux's built-in graphics capabilities, which are unique to the language. These features are designed for StratOS's direct-framebuffer rendering model.

## **16.1 The StratOS Rendering Model**

StratOS has no traditional window manager. Instead, all applications render directly to a framebuffer. Flux provides native types and intrinsics to make this seamless. The Display object represents the active framebuffer.

import std.graphics;

\# Get the display dimensions

int screenW = Display.width; # e.g., 1920

int screenH = Display.height; # e.g., 1080

\# Plot a single pixel (direct framebuffer write)

\# color32 format: 0xRRGGBBAA

Display.plot(100, 200, 0xFF0000FF); # Red pixel at (100, 200)

\# Clear the screen to a color

Display.clear(0x1A1A2EFF); # Dark navy background

\# Present the buffer (swap front/back buffer)

Display.present();

## **16.2 Low-Level Framebuffer Access**

For maximum performance (e.g., in a game engine loop), you can access the framebuffer as a raw array and write pixels directly.

\# Direct buffer write: fastest possible pixel writing

func plotPixel(int x, int y, color32 color) {

Display.buffer\[y \* Display.width + x\] = color;

}

\# Draw a filled rectangle

func fillRect(int x, int y, int w, int h, color32 color) {

for (int row = y; row < y + h; row++) {

for (int col = x; col < x + w; col++) {

Display.buffer\[row \* Display.width + col\] = color;

}

}

}

\# Example: Game render loop

func renderLoop() {

while (true) {

Display.clear(0x000000FF); # Black background

updateGameState();

renderScene();

Display.present(); # Show the frame

}

}

## **16.3 The Entity System**

For 3D development, Flux provides a scene graph with built-in entity types. Entities are high-level objects that the Flux runtime knows how to render.

import std.graphics;

import std.scene;

\# Create primitive 3D objects

Entity cube = new Primitive.Cube(size: 1.0);

Entity sphere = new Primitive.Sphere(radius: 0.5, segments: 32);

Entity plane = new Primitive.Plane(width: 10.0, depth: 10.0);

\# Load and apply a texture (Warp = texture mapping)

Texture grass = Texture.load("assets/textures/grass.png");

cube.warp(grass);

\# Position, rotate, scale

cube.position = vec3(0, 1, -5);

cube.rotation = vec3(0, 45, 0); # Degrees

cube.scale = vec3(2, 2, 2);

\# Add to the scene

Scene.add(cube);

Scene.add(sphere);

Scene.add(plane);

\# Set up camera

Camera cam = new Camera();

cam.position = vec3(0, 3, 5);

cam.lookAt(vec3(0, 0, 0));

Scene.camera = cam;

\# Render loop

while (true) {

cube.rotation.y += 1.0; # Rotate cube each frame

Scene.render();

Display.present();

}

## **16.4 Lighting**

\# Add a directional light (like the sun)

Light sun = new Light(LightType.DIRECTIONAL);

sun.direction = vec3(-1, -1, -1);

sun.color = 0xFFFFE0FF; # Warm white

sun.intensity = 1.0;

Scene.addLight(sun);

\# Add a point light (like a lamp)

Light lamp = new Light(LightType.POINT);

lamp.position = vec3(0, 5, 0);

lamp.color = 0xFF4400FF; # Orange

lamp.intensity = 2.0;

lamp.range = 20.0;

Scene.addLight(lamp);

  

# **17\. Interoperability (C++ Bridge)**

StratOS must run legacy drivers, system libraries, and other C/C++ code. Flux provides a first-class C++ bridge that lets you call C++ code directly from Flux, and vice versa.

## **17.1 Importing C++ Files**

Pass a .cpp file to the import statement just like a .lx library. The Flux compiler (which includes a Clang-based C++ backend) will compile it alongside your Flux code.

\# wrapper.flux

import "drivers/audio_driver.cpp";

import "libs/openssl.h";

func initAudio() {

\# Call C++ functions directly by their namespace

audio_driver.initialize();

audio_driver.setVolume(80);

}

## **17.2 The Build Command**

When building a project with C++ files, list them all in the build command. The linker unifies them into a single binary.

\# Build a project mixing Flux and C++

fluxc build main.flux engine.cpp renderer.cpp audio.cpp -o game.bin

\# Build a kernel module

fluxc build kernel.flux driver.cpp pci.cpp -Oz -o kernel.bin

## **17.3 Calling Flux from C++**

You can also expose Flux functions to C++ using the export keyword with C linkage.

\# In your Flux file: expose a function with C-compatible ABI

export(c) func fluxCallback(int event_code) -> int {

handleEvent(event_code);

return 0;

}

// In your C++ file: declare the Flux function as extern C

extern "C" int fluxCallback(int event_code);

void registerCallbacks() {

event_system_register_callback(fluxCallback);

}

## **17.4 Type Correspondence**

When passing data between Flux and C++, use the following type mapping:

|     |     |     |
| --- | --- | --- |
| **Flux Type** | **C++ Type** | **Notes** |
| int | int32_t | Always 32-bit signed |
| long | int64_t | Always 64-bit signed |
| float | double | Flux float = C++ double |
| byte | uint8_t | Unsigned 8-bit |
| bool | bool | ABI-compatible |
| void\* | void\* | Raw pointer (unsafe only) |

  

# **18\. Standard Library Reference**

Flux ships with a standard library organized into modules. All modules must be imported before use.

## **18.1 std.io**

|     |     |
| --- | --- |
| **Function / Object** | **Description** |
| print(string s) | Print s to stdout with a newline. |
| print_raw(string s) | Print s without a trailing newline. |
| input(string prompt) -> string | Display prompt and read a line from stdin. |
| fs.read(string path) -> string | Read entire file as UTF-8 string. |
| fs.write(string path, string data) | Write data to file (overwrites). |
| fs.append(string path, string data) | Append data to end of file. |
| fs.exists(string path) -> bool | Return true if path exists. |
| fs.delete(string path) | Delete file at path. |
| fs.list(string dir) -> List&lt;string&gt; | List files in directory. |
| fs.mkdir(string path) | Create directory (and parents). |

## **18.2 std.net**

HTTP and socket networking. In interpreted mode, HTTP requests use libcurl (supports HTTP and HTTPS). In AOT-compiled mode, plain HTTP uses raw sockets, and HTTPS requests delegate to the system `curl` command for TLS support.

|     |     |
| --- | --- |
| **Class / Function** | **Description** |
| HttpClient | HTTP 1.1 / 2.0 client. Instantiate with `new HttpClient()`. |
| .get(string url) -> Response | Send an HTTP GET request. |
| .post(string url, string body) -> Response | Send an HTTP POST request. |
| .put(string url, string body) -> Response | Send an HTTP PUT request. |
| .delete(string url) -> Response | Send an HTTP DELETE request. |
| .setHeader(string key, string value) | Set a request header for subsequent requests. |
| .download(string url, string filePath) -> bool | Download content from `url` and save it to `filePath`. Returns true on success. |
| Response.statusCode -> int | HTTP status code (e.g. 200, 404). |
| Response.body -> string | Response body as a string. |
| Response.headers -> string | Response headers as a string. |
| Socket(Protocol.TCP\|UDP) | Raw TCP/UDP socket. |
| Socket.connect(host, port) | Connect to remote host. |
| Socket.bind(port) | Bind to a local port (for servers). |
| Socket.listen(backlog) | Listen for incoming connections. |
| Socket.accept() -> Socket | Accept one incoming connection. |
| Socket.write(string data) | Send data to remote. |
| Socket.readLine() -> string | Read one line from remote. |
| Socket.close() | Close the socket connection. |

## **18.3 std.math**

|     |     |
| --- | --- |
| **Function / Constant** | **Description** |
| math.sqrt(x) -> float | Square root of x. |
| math.pow(base, exp) -> float | base raised to exp. |
| math.abs(x) -> T | Absolute value (works for int and float). |
| math.floor(x) -> float | Round down to nearest integer. |
| math.ceil(x) -> float | Round up to nearest integer. |
| math.round(x) -> float | Round to nearest integer. |
| math.min(a, b) -> T | Returns the smaller of a and b. |
| math.max(a, b) -> T | Returns the larger of a and b. |
| math.clamp(v, min, max) -> T | Clamp v to the range \[min, max\]. |
| math.lerp(a, b, t) -> float | Linear interpolation from a to b by factor t. |
| math.sin/cos/tan(x) | Standard trigonometric functions (radians). |
| math.asin/acos(x) | Inverse trigonometric functions (radians). |
| math.atan2(y, x) -> float | Arc-tangent of y/x (handles all quadrants). |
| math.log(x) -> float | Natural logarithm (base e). |
| math.log2(x) -> float | Base-2 logarithm. |
| math.log10(x) -> float | Base-10 logarithm. |
| math.exp(x) -> float | Exponential function (e^x). |
| math.PI, math.E, math.TAU, math.INF | Mathematical constants. |

## **18.4 std.collections**

|     |     |
| --- | --- |
| **Type / Method** | **Description** |
| List&lt;T&gt; | Dynamic growable array. |
| .add(item) | Append item to end. |
| .removeAt(index) | Remove item at index. |
| .contains(item) -> bool | Returns true if item exists in list. |
| .sort(comparator) | Sort in-place using comparator lambda. |
| .length -> int | Number of elements. |
| .clear() | Remove all elements. |
| Map&lt;K, V&gt; | Hash table (key-value store). |
| .put(key, value) | Insert or update a key-value pair. |
| .get(key) -> V | Get value for key. Throws if not found. |
| .hasKey(key) -> bool | Returns true if key exists. |
| .remove(key) | Remove a key-value pair. |
| Stack&lt;T&gt; | LIFO (Last-In, First-Out) stack. |
| .push(item), .pop() -> T | Add/remove from top. |
| Queue&lt;T&gt; | FIFO (First-In, First-Out) queue. |
| .enqueue(item), .dequeue() -> T | Add to back, remove from front. |

## **18.5 std.sys**

|     |     |
| --- | --- |
| **Function / Type** | **Description** |
| thread.run(func, args...) -> thread | Launch function in a new OS thread. |
| thread.join() | Wait for thread to finish. |
| thread.sleep(int ms) | Suspend current thread for ms milliseconds. |
| mutex | Mutual exclusion lock. .lock() / .unlock() |
| atomic T | Thread-safe wrapper for any primitive type. |
| sys.time() -> long | Current Unix timestamp in milliseconds. |
| sys.env(string key) -> string | Get an environment variable. |
| sys.exit(int code) | Exit the process with the given code. |
| sys.platform -> string | Operating system name ("linux", "macos", "windows"). |
| sys.arch -> string | CPU architecture ("x86_64", "aarch64", "arm"). |
| sys.args -> List&lt;string&gt; | Command-line arguments. |

## **18.6 std.json**

Parse and generate JSON data.

|     |     |
| --- | --- |
| **Function** | **Description** |
| JSON.parse(string json) -> object | Parse a JSON string into a Flux object/list. |
| JSON.stringify(object, int indent) -> string | Convert a Flux value to a JSON string. Optional indent for pretty-printing. |

```flux
import std.json;

func main() {
    string data = "{\"name\":\"Flux\",\"version\":1}";
    object obj = JSON.parse(data);
    string pretty = JSON.stringify(obj, 2);
    print(pretty);
}
```

## **18.7 std.time**

Date, time, and timer utilities.

|     |     |
| --- | --- |
| **Function / Constructor** | **Description** |
| Time.now() -> float | Current Unix timestamp in seconds. |
| Time.nowMs() -> long | Current Unix timestamp in milliseconds. |
| Time.format(float ts, string fmt) -> string | Format a timestamp using strftime patterns (e.g. "%Y-%m-%d"). |
| Time.parse(string s, string fmt) -> float | Parse a date/time string into a timestamp. |
| Time.year(float ts) -> int | Extract the year from a timestamp. |
| Time.month(float ts) -> int | Extract the month (1-12). |
| Time.day(float ts) -> int | Extract the day of month (1-31). |
| Time.hour(float ts) -> int | Extract the hour (0-23). |
| Time.minute(float ts) -> int | Extract the minute (0-59). |
| Time.second(float ts) -> int | Extract the second (0-59). |
| Time.dayOfWeek(float ts) -> int | Day of week (0 = Sunday). |
| Time.elapsed(float start) -> float | Seconds elapsed since start timestamp. |
| Timer() | Constructor. Returns a timer object with .start(), .stop(), .elapsed() methods. |

## **18.8 std.crypto**

Cryptographic hashing and encoding. All implementations are pure Flux/C++ with no external dependencies.

|     |     |
| --- | --- |
| **Function** | **Description** |
| Crypto.sha256(string data) -> string | SHA-256 hash (64-character hex string). |
| Crypto.md5(string data) -> string | MD5 hash (32-character hex string). |
| Base64.encode(string data) -> string | Encode data to Base64. |
| Base64.decode(string b64) -> string | Decode a Base64 string. |

```flux
import std.crypto;

func main() {
    print(Crypto.sha256("hello"));
    print(Base64.encode("Hello, Flux!"));
}
```

## **18.9 std.os**

Operating system interaction and process management.

|     |     |
| --- | --- |
| **Function / Property** | **Description** |
| OS.exec(string command) -> string | Execute a shell command and return its stdout output. |
| OS.execStatus(string command) -> int | Execute a command and return its exit code. |
| OS.env(string key) -> string | Get an environment variable value. |
| OS.setEnv(string key, string val) | Set an environment variable. |
| OS.cwd() -> string | Get the current working directory. |
| OS.chdir(string path) | Change the current working directory. |
| OS.pid() -> int | Get the current process ID. |
| OS.hostname() -> string | Get the system hostname. |
| OS.username() -> string | Get the current username. |
| OS.tempDir() -> string | Get the system temporary directory path. |
| OS.platform -> string | Operating system name. |

## **18.10 std.regex**

Regular expression support using ECMAScript regex syntax.

|     |     |
| --- | --- |
| **Constructor / Method** | **Description** |
| Regex(string pattern) | Create a compiled regex from a pattern string. |
| .match(string s) -> bool | Test if the entire string matches the pattern. |
| .search(string s) -> string | Find the first match in the string. Returns empty string if none. |
| .findAll(string s) -> List&lt;string&gt; | Return all matches as a list of strings. |
| .replace(string s, string replacement) -> string | Replace all matches with the replacement string. |
| .split(string s) -> List&lt;string&gt; | Split the string at each match boundary. |
| .groups(string s) -> List&lt;string&gt; | Return capture groups from the first match. |

```flux
import std.regex;

func main() {
    object r = Regex("[0-9]+");
    print(r.match("12345"));        # true
    print(r.search("abc 42 def"));  # 42
    print(r.replace("a1b2c3", "X"));# aXbXcX
}
```

## **18.11 std.gpu**

GPU compute abstraction layer. Supports CUDA, ROCm, and CPU fallback backends. GPU support is compiled conditionally — if no GPU SDK is available, functions report CPU fallback.

|     |     |
| --- | --- |
| **Function** | **Description** |
| GPU.available() -> bool | Returns true if a GPU backend is available. |
| GPU.backend() -> string | Returns "CUDA", "ROCm", or "CPU Fallback". |
| GPU.deviceCount() -> int | Number of available GPU devices. |
| GPU.deviceName(int id) -> string | Name of GPU device at index. |
| GPU.allocate(int count) -> int | Allocate GPU memory for count floats. Returns a handle. |
| GPU.memcpyToDevice(int handle, List data) | Copy data from host to device. |
| GPU.memcpyToHost(int handle, int count) -> List | Copy data from device to host. |
| GPU.free(int handle) | Free GPU memory. |
| GPU.sync() | Synchronize all GPU streams. |

## **18.12 std.graphics**

Window creation, 2D drawing, text rendering, and image loading. Supports SDL2 (with SDL2_ttf for text, SDL2_image for images) and GLFW (for OpenGL 3D rendering) backends, compiled conditionally. When both SDL2 and GLFW are available, windows start in SDL2 mode for 2D and can switch to GLFW+OpenGL via `enable3D()`. If only one backend is available, it will be used exclusively. If neither is present, all window operations will report an error.

The `.backend` field reports the active configuration: `"sdl2+glfw"`, `"sdl2"`, `"glfw"`, or `"none"`.

### Window Lifecycle

|     |     |
| --- | --- |
| **Constructor / Function** | **Description** |
| Window(string title, int width, int height) | Create a new window. Returns a window object. |
| .isOpen() -> bool | Returns true if the window is still open. |
| .pollEvents() | Process pending window events. |
| .clear(int r, int g, int b) | Clear the window with an RGB color (0-255 each). |
| .present() | Swap buffers / display the current frame. |
| .close() | Close and destroy the window. |
| .setTitle(string title) | Change the window title. |
| .resize(int w, int h) | Resize the window. |
| .setBlendMode(string mode) | Set the blend mode ("none", "blend", "add", "mod"). |

### Basic Drawing Primitives

|     |     |
| --- | --- |
| **Method** | **Description** |
| .drawPixel(int x, int y, int r, int g, int b) | Draw a single pixel at (x,y) with RGB color. |
| .drawLine(int x1, int y1, int x2, int y2, int r, int g, int b) | Draw a line between two points. |
| .drawRect(int x, int y, int w, int h, int r, int g, int b) | Draw a rectangle outline. |
| .fillRect(int x, int y, int w, int h, int r, int g, int b) | Draw a filled rectangle. |
| .drawCircle(int cx, int cy, int radius, int r, int g, int b) | Draw a circle outline. |
| .fillCircle(int cx, int cy, int radius, int r, int g, int b) | Draw a filled circle. |
| .drawTriangle(int x1, int y1, int x2, int y2, int x3, int y3, int r, int g, int b) | Draw a triangle outline. |
| .fillTriangle(int x1, int y1, int x2, int y2, int x3, int y3, int r, int g, int b, int a) | Draw a filled triangle. Alpha channel optional (default 255). |

### Extended Shapes

|     |     |
| --- | --- |
| **Method** | **Description** |
| .drawEllipse(int cx, int cy, int rx, int ry, int r, int g, int b, int a) | Draw an ellipse outline. Alpha optional. |
| .fillEllipse(int cx, int cy, int rx, int ry, int r, int g, int b, int a) | Draw a filled ellipse. Alpha optional. |
| .drawRoundedRect(int x, int y, int w, int h, int radius, int r, int g, int b, int a) | Draw a rounded rectangle outline. Alpha optional. |
| .fillRoundedRect(int x, int y, int w, int h, int radius, int r, int g, int b, int a) | Draw a filled rounded rectangle. Alpha optional. |

### Text Rendering (requires SDL2_ttf)

|     |     |
| --- | --- |
| **Method** | **Description** |
| .drawText(string text, int x, int y, string fontPath, int fontSize, int r, int g, int b, int a) | Render text at (x,y) using a TTF font file. Alpha optional. |
| .measureText(string text, string fontPath, int fontSize) -> list | Returns `[width, height]` of the rendered text without drawing it. |

### Image Loading (requires SDL2_image)

|     |     |
| --- | --- |
| **Method** | **Description** |
| .drawImage(string path, int x, int y) | Draw an image (PNG, JPG, etc.) at (x,y) at its native size. |
| .drawImageScaled(string path, int x, int y, int w, int h) | Draw an image scaled to the given width and height. |
| .getImageSize(string path) -> list | Returns `[width, height]` of the image without drawing it. |

### 3D Rendering (requires GLFW + OpenGL)

Calling `enable3D()` transitions the window from 2D (SDL2) to 3D (GLFW+OpenGL). Once in 3D mode, 2D drawing methods are unavailable. The transition destroys the SDL2 window and creates a GLFW window with an OpenGL context.

|     |     |
| --- | --- |
| **Method** | **Description** |
| .enable3D() | Switch window to 3D mode (GLFW + OpenGL). Enables depth testing and backface culling. |
| .disable3D() | Disable depth testing and culling (remains in GLFW mode). |
| .clearDepth() | Clear the depth buffer. Call after `clear()` each frame for correct depth ordering. |
| .setPerspective(float fov, float aspect, float near, float far) | Set a perspective projection matrix. Typical: `setPerspective(60.0, 800.0/600.0, 0.1, 100.0)`. |
| .setCamera(float eyeX, float eyeY, float eyeZ, float centerX, float centerY, float centerZ, float upX, float upY, float upZ) | Set the camera (view) matrix using eye position, look-at point, and up vector. |
| .pushMatrix() | Push the current model-view matrix onto the stack. |
| .popMatrix() | Pop the model-view matrix from the stack. |
| .translate(float x, float y, float z) | Translate (move) subsequent geometry. |
| .rotate(float angle, float x, float y, float z) | Rotate subsequent geometry by `angle` degrees around the axis (x, y, z). |
| .scale(float x, float y, float z) | Scale subsequent geometry. |
| .loadTexture(string path) -> int | Load an image file as an OpenGL texture. Returns a texture ID (0 on failure). |
| .bindTexture(int texId) | Bind a texture for subsequent draw calls. Pass 0 to unbind. |
| .drawTexturedCube(float size, int texId) | Draw a textured cube centered at the origin. |
| .setColor(float r, float g, float b, float a) | Set the current OpenGL color for untextured geometry. Values are 0.0-1.0. Alpha defaults to 1.0. |
| .drawQuad(x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4) | Draw a flat quad (four vertices). Useful for floors, walls, and procedural geometry. Uses the current color set by `setColor()`. |

### Window Input Methods

Window objects provide direct input polling methods in addition to the static `Input` namespace.

|     |     |
| --- | --- |
| **Method** | **Description** |
| .keyPressed(string key) -> bool | Returns true if the specified key is currently pressed. Works in both 2D and 3D mode. |
| .getMousePos() -> list | Returns `[x, y]` mouse position relative to the window. |
| .setMousePos(int x, int y) | Warp the mouse cursor to the given window coordinates. |
| .setCursorMode(string mode) | Set cursor mode: `"disabled"` hides and captures the cursor, `"normal"` restores it. |
| .mouseButtonPressed(int button) -> bool | Check mouse button state. 0 = left, 1 = middle, 2 = right. |

### Input

|     |     |
| --- | --- |
| **Function** | **Description** |
| Input.keyPressed(string key) -> bool | Returns true if the specified key is currently pressed. |
| Input.mouseX() -> int | Current mouse X position. |
| Input.mouseY() -> int | Current mouse Y position. |
| Input.mouseDown(int button) -> bool | Returns true if the specified mouse button is down. |

  

## **18.13 std.audio**

Audio playback and sound generation using SDL2_mixer. Supports loading audio files (WAV, OGG, MP3) and generating tones programmatically.

Requires SDL2_mixer to be installed on the system (`libsdl2-mixer-dev`). All functions are accessed through the `Audio` namespace object.

### Audio Lifecycle

|     |     |
| --- | --- |
| **Function** | **Description** |
| Audio.init() -> bool | Initialize the audio subsystem. Must be called before any other audio functions. Returns true on success. |
| Audio.quit() | Shut down the audio subsystem and free all loaded sounds and music. |

### Loading Audio

|     |     |
| --- | --- |
| **Function** | **Description** |
| Audio.loadSound(string path) -> int | Load a sound file (WAV, OGG). Returns a sound ID, or -1 on failure. |
| Audio.loadMusic(string path) -> int | Load a music file (WAV, OGG, MP3). Returns a music ID, or -1 on failure. |
| Audio.generateTone(int freq, int durationMs) -> int | Generate a sine wave tone at the given frequency and duration. Returns a sound ID. No external files needed. |

### Playback Control

|     |     |
| --- | --- |
| **Function** | **Description** |
| Audio.playSound(int id, int loops) -> int | Play a sound. `loops=0` plays once, `loops=1` plays twice, etc. Returns the channel number. |
| Audio.playMusic(int id, int loops) | Play music. `loops=-1` loops forever, `loops=0` plays once. |
| Audio.stopMusic() | Stop the currently playing music. |
| Audio.pauseMusic() | Pause the currently playing music. |
| Audio.resumeMusic() | Resume paused music. |
| Audio.isPlayingMusic() -> bool | Returns true if music is currently playing. |
| Audio.stopChannel(int channel) | Stop playback on a specific channel. |

### Volume Control

|     |     |
| --- | --- |
| **Function** | **Description** |
| Audio.setSoundVolume(int id, int vol) | Set volume for a loaded sound (0-128). |
| Audio.setMusicVolume(int vol) | Set the global music volume (0-128). |

### Example

```flux
import std.audio;

func main() {
    Audio.init();

    # Generate sound effects programmatically
    int beep = Audio.generateTone(440, 200);    # A4 note, 200ms
    int buzz = Audio.generateTone(220, 300);    # A3 note, 300ms

    # Play sounds
    Audio.playSound(beep, 0);                   # Play once

    # Load and play a music file
    int music = Audio.loadMusic("background.ogg");
    if (music >= 0) {
        Audio.setMusicVolume(64);               # Half volume
        Audio.playMusic(music, -1);             # Loop forever
    }

    Audio.quit();
}
```

  

## **18.14 std.video**

Video playback using FFmpeg for decoding and OpenGL for texture upload. Supports MP4, AVI, MKV, WebM, MOV, and any format that FFmpeg can decode. Video frames are decoded to RGB pixel data and can be uploaded as OpenGL textures for rendering on 3D geometry.

Requires FFmpeg development libraries (`libavcodec-dev`, `libavformat-dev`, `libswscale-dev`, `libswresample-dev`, `libavutil-dev`). Optional: SDL2_mixer for audio track playback, GLFW+OpenGL for texture upload.

### Video Constructor

|     |     |
| --- | --- |
| **Function** | **Description** |
| Video(string path) -> Video | Open a video file for playback. Returns a Video object with metadata and decode methods. |

### Video Metadata

|     |     |
| --- | --- |
| **Method** | **Description** |
| .isOpen() -> bool | Returns true if the video was opened successfully. |
| .width() -> int | Width of the video in pixels. |
| .height() -> int | Height of the video in pixels. |
| .fps() -> float | Frames per second of the video stream. |
| .duration() -> float | Duration of the video in seconds. |
| .isFinished() -> bool | Returns true if all frames have been decoded. |

### Frame Decoding

|     |     |
| --- | --- |
| **Method** | **Description** |
| .nextFrame() -> bool | Decode the next video frame. Returns true if a frame was decoded, false if the video has ended. |
| .getTextureId() -> int | Upload the current decoded frame to an OpenGL texture. Returns the GL texture ID. Subsequent calls update the same texture. |
| .seek(float seconds) | Seek to a specific time in the video. Resets the finished state. |
| .restart() | Seek back to the beginning of the video. |
| .close() | Close the video and free all FFmpeg resources and OpenGL textures. |

### Audio Track

|     |     |
| --- | --- |
| **Method** | **Description** |
| .playAudio() | Play the audio track extracted from the video. Requires buffered audio data (call nextFrame() first). |
| .stopAudio() | Stop audio track playback. |
| .setAudioVolume(int vol) | Set audio volume (0-128). |

### Example: Video Info

```flux
import std.video;

func main() {
    var vid = Video("clip.mp4");
    print("Size: " + toString(vid.width()) + "x" + toString(vid.height()));
    print("FPS: " + toString(vid.fps()));
    print("Duration: " + toString(vid.duration()) + "s");

    # Decode first 5 frames
    var count = 0;
    while (vid.nextFrame() && count < 5) {
        count = count + 1;
    }
    print("Decoded " + toString(count) + " frames");

    vid.close();
}
```

### Example: 3D Video Playback

```flux
import std.graphics;
import std.video;

func main() {
    var vid = Video("clip.mp4");
    var win = Window3D("Player", 800, 600);
    var input = Input();
    var interval = 1.0 / vid.fps();
    var lastTime = 0.0;

    while (win.isOpen()) {
        input.poll();
        if (input.isKeyDown("ESCAPE")) { break; }

        var now = win.getTime();
        if (now - lastTime >= interval) {
            if (!vid.nextFrame()) { break; }
            lastTime = now;
        }

        win.clear(0.0, 0.0, 0.0, 1.0);
        var tex = vid.getTextureId();
        if (tex > 0) {
            win.bindTexture(tex);
            win.drawQuad(-1.0, 1.0, 0.0, 1.0, 1.0, 0.0,
                          1.0, -1.0, 0.0, -1.0, -1.0, 0.0);
        }
        win.swap();
    }

    vid.close();
    win.close();
}
```

  

# **19\. StratOS Desktop Environment**

StratOS includes a compositing desktop environment built entirely in Flux. The system consists of a shell (text terminal), a compositor (graphical window manager), a desktop surface with wallpapers and icons, a taskbar, and an interactive TUI installer.

## **19.1 Shell**

The StratOS shell provides a Unix-like command-line interface rendered via the kernel console. It supports command history (Up/Down arrows), tab-influenced navigation, scroll buffer (PageUp/PageDown), and a full set of built-in commands.

### Built-in Commands

| Command | Description |
|---------|-------------|
| `help` | List all available commands |
| `clear` | Clear the screen |
| `echo <text>` | Print text to console |
| `ls [path]` | List directory contents |
| `cd <path>` | Change directory |
| `pwd` | Print working directory |
| `cat <file>` | Display file contents |
| `touch <file>` | Create an empty file |
| `mkdir <dir>` | Create a directory |
| `rm [-rf] <path>` | Remove a file or directory |
| `cp <src> <dst>` | Copy a file |
| `mv <src> <dst>` | Move or rename a file |
| `write <file> <text>` | Write text to a file |
| `head <file> [n]` | Show first n lines |
| `wc <file>` | Word/line/byte count |
| `grep <pattern> <file>` | Search for text in a file |
| `find <path> <name>` | Find files by name |
| `chmod <mode> <file>` | Change file permissions (display only) |
| `chown <user> <file>` | Change file owner (display only) |
| `df` | Disk usage statistics |
| `id` | Display current user identity |
| `which <cmd>` | Show command location |
| `man <cmd>` | Display manual page |
| `dmesg` | Show kernel boot messages |
| `whoami` | Print current username |
| `hostname` | Print system hostname |
| `date` | Display simulated system date |
| `uptime` | Display system uptime |
| `uname [-a]` | System information |
| `env` | Show environment variables |
| `export K=V` | Set an environment variable |
| `ping <host>` | Simulated network ping |
| `sudo <cmd>` | Run command as root |
| `su` | Switch to root user |
| `exit` | Exit root session or shell |
| `startx` | Launch the graphical desktop |
| `wallpaper <sub>` | Manage desktop wallpapers |
| `install` | Launch the TUI installer |
| `quantum <sub>` | Package manager (see below) |
| `flux` | Enter the Flux REPL |

### Root User

The shell supports a root user mode. Use `su` to switch to root (password: `root`). The prompt changes from `$` to `#` and displays in red. Use `sudo <command>` to run a single command as root.

### Scroll Buffer

The console maintains a 500-line scroll buffer. Use **PageUp** and **PageDown** to scroll through output history. A scroll indicator appears at the top right when scrolled above the current output.

## **19.2 Quantum Package Manager**

Quantum is the built-in package manager for StratOS. It manages software packages from a configurable server URL.

### Commands

```
quantum install <pkg>     # Install a package
quantum remove <pkg>      # Remove a package
quantum search <query>    # Search the registry
quantum info <pkg>        # Show package details
quantum list              # List installed packages
quantum update            # Update package registry
quantum set-url <url>     # Set package server URL
quantum get-url           # Show current server URL
```

### Features

- **URL Configuration**: Default server at `stratos.skinnertopia.com`. Configurable with `set-url`/`get-url`.
- **SHA256 Verification**: Package integrity is verified via SHA256 checksums.
- **Confirmation Prompts**: Interactive Y/n prompts before install/remove operations.
- **Registry**: Packages include `flux`, `compiler`, `neofetch`, `htop`, `nano`, `git`, `gcc`, `python`, `rust`, `node`.

## **19.3 Desktop Compositor**

The compositor provides a compositing window manager accessible via the `startx` command. It renders directly to the kernel framebuffer.

### Architecture

The compositor manages:
- **Desktop surface** — background wallpaper and icons
- **Window stack** — draggable, resizable application windows with title bars
- **Taskbar** — system tray, clock, application switcher
- **Input routing** — keyboard and mouse event dispatching

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+T` | Open a new terminal window |
| `Ctrl+W` | Cycle to next wallpaper |
| `Ctrl+Q` | Close focused window |
| `Ctrl+G` | Auto-tile all visible windows in a grid |
| `Ctrl+D` | Show Desktop (minimize all / restore all toggle) |
| `Ctrl+N` | Toggle notification history panel |
| `Ctrl+P` | Take a screenshot (flash + save metadata) |
| `Ctrl+B` | Cycle through desktop themes |
| `Ctrl+/` | Show keyboard shortcuts overlay |
| `Ctrl+F1` | Lock the screen |
| `Ctrl+F3` | Switch to TTY / exit desktop |
| `Alt+Left` | Snap window to left half |
| `Alt+Right` | Snap window to right half |
| `Alt+Up` | Maximize window |
| `Alt+Down` | Restore window |
| `Alt+F4` | Close focused window |
| `Alt+Tab` | Cycle focus between windows |
| `Delete` | Remove selected desktop icon |

### Window Management

Windows support drag-resize from all edges and corners. The cursor changes shape to indicate the available action:

| Context | Cursor Style |
|---------|-------------|
| Default desktop | Arrow |
| Window edge | Resize arrows (horizontal, vertical, or diagonal) |
| Title bar | Move (four-way arrow) |
| Title bar buttons | Hand pointer |
| Text apps (editor, terminal, notes) | I-beam text cursor |
| Taskbar | Hand pointer |

Window minimize/restore is animated with a 6-frame sliding scale transition toward/from the taskbar.

Auto-tiling (`Ctrl+G`) arranges all visible windows in a grid layout, calculating optimal rows and columns based on window count (1 window = full area, 2 = side-by-side, 3-4 = 2×2, 5-6 = 3×2, etc.).

### Desktop Clock & Calendar Widget

A translucent floating widget can be toggled with `Ctrl+D`. It displays:
- Current time in HH:MM:SS format at 2x scale
- Full date (month, day, year)
- Full month calendar grid with day-of-week headers
- Current day highlighted in blue

The calendar uses Zeller's formula to compute the first day of the month and supports leap year detection for accurate February rendering.

### Snap Zone Preview

When dragging a window toward a screen edge, a semi-transparent blue overlay appears showing the target snap zone before the window is dropped:

| Drag Position | Preview Zone |
|---------------|-------------|
| Left edge | Left half of screen |
| Right edge | Right half of screen |
| Top edge | Full screen (maximize) |

The preview uses a rounded rectangle border with alternating-pixel transparency for a lightweight visual effect.

### Show Desktop

`Ctrl+D` toggles between minimizing all open windows and restoring them. A toast notification confirms the action.

### Lock Screen

The lock screen (`Ctrl+F1`) provides password-protected screen locking with:
- Full-screen dark gradient overlay
- Large animated RTC clock with glow effect
- Date display and StratOS branding
- Masked password input with dot indicators
- Shake animation on incorrect password entry
- Optional auto-lock after configurable idle timeout (disabled by default)
- Default password: `stratos` (changeable via `LockScreen.setPassword()`)

### Screensaver

An animated starfield screensaver activates after approximately 5 minutes of idle time. Features:
- 32 animated stars with depth-based perspective projection
- Stars grow larger and brighter as they approach the viewer
- Floating digital clock with glow effect
- Dismissed by any key press or mouse movement
- Configurable idle timeout (default: ~5 minutes at 60fps)
- Can be enabled/disabled via `Screensaver.toggle()`

### Keyboard Shortcuts Overlay

`Ctrl+/` opens a full-screen semi-transparent overlay displaying all available keyboard shortcuts organized in a two-column layout by category:
- Desktop, Window Management, System Tray
- Text Editor, File Explorer, Browser, Calculator, Notes

Each shortcut is rendered as a styled key badge with a description. Press any key to dismiss.

### Theme System

The desktop supports four built-in color themes, cycled with `Ctrl+B`:

| Theme | Description |
|-------|-------------|
| Cosmic Dark | Default deep space dark theme |
| Arctic Light | Light theme with cool blue accents |
| Ocean Blue | Deep blue tones with cyan highlights |
| Forest Green | Earth tones with green accents |

Each theme defines 28+ color variables covering window backgrounds, title bars, taskbar, text, accents, and borders. A toast notification shows the active theme name on switch.

### System Tray

The taskbar system tray (right side) includes:
- **Volume icon** — click to open a vertical volume slider popup with drag support
- **Network icon** — connectivity status indicator
- **Bell icon** — notification indicator with unread count badge; click to toggle the notification panel
- **Lock icon** — shows auto-lock status; click to lock the screen immediately

### Notification History

All toast notifications are recorded in a history buffer (up to 20 entries). Toggle the notification history panel with `Ctrl+N`. The panel shows past notifications with color-coded type indicators (info, success, warning, error) and supports scrolling with arrow keys. Press `C` to clear all notifications or `Escape` to close.

### App Launcher Search

The app launcher (opened with Super key) supports type-to-filter search. Begin typing an application name to filter the displayed list. The search is case-insensitive and matches against application names.

### Screenshot

`Ctrl+P` captures a screenshot. The screen flashes white as visual feedback, a click sound plays, and a metadata file is saved to `/home/pictures/screenshot_N.txt` with a timestamp.

### Startup Splash

StratOS displays a 60-frame animated boot splash before the desktop loads, featuring a progressive star field, expanding circle logo, "StratOS" text with subtitle fade-in, and a loading progress bar.

### Theme Implementation

Theme colors are defined in `theme.lx`. All colors, dimensions, and visual constants are centralized as static members of the `Theme` class. The theme system supports runtime switching between four preset themes:

```flux
class Theme {
    public static color32 desktopBgTop = 0x0A0E1AFF;
    public static color32 windowBg = 0x161B22FF;
    public static int TITLEBAR_HEIGHT = 32;
    // ...
    
    public static func cycle() -> string { ... }
    public static func applyTheme(int index) -> void { ... }
    public static func withAlpha(color32 base, int alpha) -> color32 { ... }
    public static func darken(color32 base, float factor) -> color32 { ... }
}
```

## **19.4 Desktop Wallpapers & Icons**

The desktop surface supports multiple procedural wallpapers and a grid-based icon system.

### Wallpapers

Four built-in wallpapers are rendered procedurally (no external image files):

| Index | Name | Description |
|-------|------|-------------|
| 0 | Void | Deep space gradient with twinkling stars and glow effects |
| 1 | Nebula | Purple-blue cosmic clouds using layered sine wave functions |
| 2 | Aurora | Northern lights curtains with green-blue gradients over rolling hills |
| 3 | Mountain | Warm sunset sky with layered mountain silhouettes |

All wallpapers use the `sinApprox()` Taylor series approximation for trigonometric effects without requiring a math library.

### Managing Wallpapers

```bash
wallpaper list          # List available wallpapers with descriptions
wallpaper set <n>       # Set wallpaper by index (0-3)
wallpaper next          # Cycle to next wallpaper
```

Or use **Ctrl+W** in the desktop to cycle wallpapers.

### Desktop Icons

Default icons on the desktop grid:

| Icon | Application Type | Shape |
|------|-----------------|-------|
| Terminal | terminal | `>_` cursor prompt |
| Files | explorer | Folder silhouette |
| Editor | editor | Document with lines |
| Browser | browser | Globe with lines |
| Music | music | Note with stem |
| Settings | settings | Gear with tick marks |
| Trash | trash | Open container |
| Monitor | sysmon | System monitor |
| Help | help | Help manual |
| Snake | snake | Snake game |

Icons can be rearranged by dragging with the mouse. Double-clicking launches the associated application. Selected icons can be deleted with the `Delete` key. Icons snap to the nearest available grid position.

## **19.5 Applications**

### System Monitor

The system monitor (`sysmon`) displays running processes with their window IDs, types, and status (Active/Minimized). Features:
- Uptime and process count header
- Sortable process list with keyboard navigation (Up/Down)
- Kill process (Delete/Backspace) or focus process (Enter)
- Click to select, with Kill and Focus buttons

### Help Viewer

The help viewer (`help`) provides documentation for all StratOS features across six sections:
- **Desktop** — wallpaper cycling, icon management, shortcuts
- **Editor** — line numbers, keyboard shortcuts, undo (Ctrl+Z)
- **Terminal** — commands, theme cycling (Ctrl+T), shell features
- **Files** — navigation, file operations, keyboard controls
- **Browser** — VoidSearch encyclopedia, URL navigation
- **About** — System information and credits

Navigate sections with Tab or sidebar clicks. Scroll content with Up/Down/PgUp/PgDn.

### Snake Game

A classic Snake game built into StratOS as a native application. The game uses direct framebuffer rendering within the windowing system.

**Controls:**

| Key | Action |
|-----|--------|
| Arrow Keys | Change direction |
| Space | Start / Restart |

**Features:**
- 30×20 grid with centered rendering
- Score tracking and length display
- Progressive speed increase (every 50 points)
- Title screen with decorative snake gradient
- Game over overlay with final score
- Click anywhere to restart from title or game over screen

The game is accessible from the desktop icon grid, the app launcher, or via the terminal `launch snake` command.

### Editor

The editor supports undo operations:
- `Ctrl+Z` — Undo last edit (up to 50 levels)
- Undo tracks single-line edits, line splits (Enter), and line merges (Backspace/Delete across lines)
- Line numbers displayed in a gutter

### Terminal

Six color themes available, cycled with `Ctrl+T`:

| Theme | Background | Description |
|-------|-----------|-------------|
| GitHub Dark | `#0D1117` | Default dark theme |
| Light | `#FFFFFF` | Light mode with dark text |
| Solarized Dark | `#002B36` | Warm dark palette |
| Dracula | `#282A36` | Purple-accented dark theme |
| Nord | `#2E3440` | Cool blue-gray tones |
| Matrix | `#000000` | Green-on-black hacker style |

### Taskbar Clock

The taskbar displays the current time from the CMOS Real-Time Clock. Clicking the clock area opens a popup showing:
- Day of the week
- Full date (Month Day, Year)
- Large HH:MM:SS display
- System uptime

## **19.5 TUI Installer**

The StratOS installer is an 8-step interactive TUI (Text User Interface) wizard accessible via the `install` command.

### Installation Steps

1. **Welcome** — ASCII art logo, system requirements display
2. **Disk Setup** — Simulated RAM disk partition table overview
3. **User Configuration** — Set username, hostname, and password via interactive text fields
4. **Profile Selection** — Choose between Desktop, Minimal, or Developer profiles using arrow key navigation
5. **Confirmation** — Summary of all configuration choices
6. **Installation** — Animated progress bar with step-by-step status messages
7. **Configuration** — Writes settings to the filesystem:
   - `/etc/hostname`, `/etc/passwd`, `/etc/os-release`
   - User home directory with Documents, Downloads, Desktop, `.config`
   - `/etc/quantum/sources.conf` with package server URL
   - `/var/log/install-receipt`
8. **Complete** — Keyboard shortcut reference and next steps

### Profiles

| Profile | Description |
|---------|-------------|
| Desktop | Full desktop environment with all applications and themes |
| Minimal | Core system only, no desktop environment |
| Developer | Desktop plus development tools (compiler, debugger, profiler) |

### Navigation

- **Arrow keys** — Navigate between options in profile selection
- **Enter** — Confirm selection and proceed
- **Escape** — Go back to previous step
- **Backspace** — Delete characters in text fields

After installation completes, the shell updates its username, hostname, and home directory to match the configured values.


# **20\. Native Code Execution**

StratOS supports compiling and running native ELF64 binaries directly within the operating system. This enables Flux programs, C++ code, and any statically-linked x86_64 binary to execute on StratOS without requiring an external host.

## **20.1 Execution Pipeline**

The full pipeline from Flux source to execution:

```
.flux source → Flux compiler (transpile) → .cpp source → Clang (compile) → ELF64 binary → StratOS kernel (execute)
```

Each stage:

1. **Flux Transpile** — The Flux compiler reads `.flux` source and produces equivalent C++ source code. This is the same compiler used on the host during development.
2. **C++ Compile** — A statically-linked Clang + LLD + libc++ toolchain, bundled into the StratOS filesystem, compiles the C++ source into a static ELF64 binary linked against musl libc.
3. **ELF Load** — The kernel's ELF loader parses the binary, maps PT_LOAD segments into memory, sets up a user stack, and transfers control.
4. **Execute** — The binary runs either in Ring 3 (user space, isolated) or Ring 0 (kernel space, trusted).

## **20.2 Execution Modes**

### Ring 3 — User Space (Default)

User programs run in Ring 3 with full hardware isolation. Memory accesses are restricted to pages mapped with the USER bit. System calls use the `SYSCALL` instruction and follow the Linux x86_64 ABI:

| Register | Purpose |
| --- | --- |
| RAX | Syscall number |
| RDI | Argument 1 |
| RSI | Argument 2 |
| RDX | Argument 3 |
| R10 | Argument 4 |
| R8  | Argument 5 |
| R9  | Argument 6 |
| RAX | Return value |

The kernel dispatches syscalls to a Linux-compatible implementation that provides file I/O, memory mapping, process control, and more.

### Ring 0 — Trusted Execution

Trusted programs (the compiler toolchain, system utilities) run in Ring 0 with full kernel privileges. This avoids the overhead of context switches for performance-critical system tools. Ring 0 execution requires root privileges from the shell.

## **20.3 Supported Syscalls**

The syscall layer implements approximately 30 Linux-compatible syscalls:

| Number | Name | Description |
| --- | --- | --- |
| 0 | read | Read from a file descriptor |
| 1 | write | Write to a file descriptor |
| 2 | open | Open a file |
| 3 | close | Close a file descriptor |
| 4 | stat | Get file status by path |
| 5 | fstat | Get file status by descriptor |
| 8 | lseek | Reposition file offset |
| 9 | mmap | Map memory (anonymous only) |
| 11 | munmap | Unmap memory |
| 12 | brk | Set program break (heap) |
| 16 | ioctl | Device control |
| 21 | access | Check file accessibility |
| 39 | getpid | Get process ID |
| 60 | exit | Terminate process |
| 63 | uname | Get system information |
| 79 | getcwd | Get working directory |
| 80 | chdir | Change working directory |
| 82 | rename | Rename a file |
| 83 | mkdir | Create a directory |
| 87 | unlink | Delete a file |
| 89 | readlink | Read symbolic link target |
| 158 | arch_prctl | Set FS/GS base (TLS support) |
| 228 | clock_gettime | Get clock time |
| 257 | openat | Open file relative to directory |
| 262 | newfstatat | Get file status relative to directory |
| 318 | getrandom | Get random bytes |

File descriptors 0 (stdin), 1 (stdout), and 2 (stderr) are pre-opened. Writing to stdout or stderr outputs to the StratOS console.

## **20.4 ELF Loader**

The ELF loader supports static ELF64 binaries for the x86_64 architecture:

- Validates the ELF magic number, class (64-bit), endianness (little), and machine (x86_64)
- Loads all PT_LOAD segments, allocating physical frames and mapping pages with correct permissions
- Zeroes BSS regions (where memory size exceeds file size)
- Sets up a 1MB user stack at 0x7FFFFFFFE000 for Ring 3 programs
- Allocates a 64KB kernel stack for Ring 0 programs

Requirements for binaries:
- Must be statically linked (no dynamic linker support)
- Must target x86_64 Linux (ET_EXEC type)
- Entry point must be defined (standard `_start` or `main`)

## **20.5 Shell Commands**

### `cc` — Compile C++ Source

```
cc <source.cpp> [-o output]
cc <source.flux> [-o output]
```

Compiles a C++ or Flux source file to a native ELF binary. If the source is a `.flux` file, it is first transpiled to C++ before compilation.

Options:
- `-o <file>` — Set the output binary name (default: input name without extension)
- `--trusted` — Run the compiler in Ring 0 (default for compiler)

### `run` — Execute an ELF Binary

```
run <binary> [--trusted]
```

Loads and executes a static ELF64 binary. By default, programs run in Ring 3 (user space).

Options:
- `--trusted` — Run in Ring 0 (kernel space); requires root privileges

### `flux` — Flux REPL

```
flux
```

Enters the interactive Flux read-eval-print loop. Type `exit` to return to the shell.

## **20.6 Toolchain**

StratOS bundles a statically-linked C++ toolchain based on:

- **Clang 17** — C/C++ compiler
- **LLD** — LLVM linker
- **libc++** — C++ standard library (no exceptions, no RTTI)
- **musl** — C standard library
- **compiler-rt** — Compiler runtime builtins

The toolchain targets `x86_64-linux-musl` and produces fully static ELF binaries. The build script for the toolchain is located at `tools/build_toolchain.sh`.

## **20.7 Memory Layout for User Programs**

```
0x0000000000400000  — Program text/data (typical ELF load address)
    ...
0x00007FFFFFFE0000  — User stack top (1MB stack, grows downward)
0x00007FFFFFFFE000  — User stack base
```

The kernel identity-maps the first 4GB at boot using 2MB pages. User program segments are mapped at 4KB granularity with proper permissions. All intermediate page table entries carry the USER bit to ensure Ring 3 accessibility.

## **20.8 TSS and Context Switching**

The Task State Segment (TSS) stores:
- **RSP0** — Kernel stack pointer for Ring 3 → Ring 0 transitions (via SYSCALL or interrupt)
- **IST1** — Interrupt Stack Table entry 1 for critical exception handling

When switching between user processes, the kernel updates TSS.RSP0 to point to the new process's kernel stack, ensuring that syscalls and interrupts land on the correct stack.

## **20.9 GDT Segment Layout**

| Offset | Segment | DPL | Description |
| --- | --- | --- | --- |
| 0x00 | Null | — | Required null descriptor |
| 0x08 | Kernel Code | 0 | 64-bit kernel code segment |
| 0x10 | Kernel Data | 0 | Kernel data segment |
| 0x18 | User Data | 3 | User-mode data segment |
| 0x20 | User Code | 3 | 64-bit user-mode code segment |
| 0x28 | TSS (low) | 0 | Task State Segment descriptor |
| 0x30 | TSS (high) | 0 | TSS descriptor upper 8 bytes |

The segment ordering is compatible with the SYSCALL/SYSRET instruction pair. The STAR MSR is configured so that SYSCALL loads CS=0x08/SS=0x10 (kernel) and SYSRET loads CS=0x20+16=0x23/SS=0x20+8=0x1B (user, adding RPL=3).


# **21\. Persistent Storage & Networking**

StratOS includes persistent filesystem support and an integrated TCP/IP network stack operating directly on bare metal hardware.

## **21.1 Persistent Filesystem**

StratOS uses a custom on-disk filesystem called **StratFS** that persists data across reboots via an ATA PIO disk driver.

### Disk Driver

The ATA PIO driver (`kernel/drivers/disk.lx`) communicates with IDE hard disks using port-mapped I/O on the primary controller (base 0x1F0). It supports LBA28 addressing for sector-level read/write operations.

| Function | Description |
| --- | --- |
| `Disk.init()` | Detects and initializes the ATA primary master |
| `Disk.isPresent()` | Returns true if a disk was detected |
| `Disk.readSectors(lba, count, buffer)` | Reads sectors from disk into memory |
| `Disk.writeSectors(lba, count, buffer)` | Writes sectors from memory to disk |
| `Disk.getSectorCount()` | Returns the total number of sectors |

### StratFS Layout

The filesystem uses a simple fixed-layout design:

| Region | Size | Description |
| --- | --- | --- |
| Superblock | 1 sector | Magic number, block/inode counts, metadata |
| Block Bitmap | Variable | Tracks free/used data blocks |
| Inode Table | 512 sectors | 2048 inodes × 128 bytes each |
| Data Blocks | Remainder | 2048 bytes per block |

Inodes store file metadata (type, size, parent inode, start block, block count). Directories are stored as inode entries with child listings in data blocks.

### VFS Persistence

The Virtual Filesystem (`system/fs/vfs.lx`) operates as a RAM cache backed by StratFS. All mutations (write, mkdir, rm, cp, mv, append) set a dirty flag. The `sync` shell command or `VFS.sync()` flushes changes to disk.

On boot, if a formatted StratFS disk is detected, the VFS loads the entire directory tree from disk. If no filesystem exists, the disk is formatted automatically and populated with default directories.

### Shell Commands

| Command | Description |
| --- | --- |
| `sync` | Flush VFS changes to the persistent disk |

### QEMU Disk Configuration

StratOS uses a 64MB raw disk image attached as an IDE drive:

    -drive file=build/stratos-disk.img,format=raw,if=ide,index=0

The disk image persists across reboots. Use `make disk-reset` to recreate it.

## **21.2 PCI Bus Driver**

The PCI subsystem (`kernel/drivers/pci.lx`) enumerates devices on the PCI bus at boot time using configuration space access via I/O ports 0xCF8 (address) and 0xCFC (data).

| Function | Description |
| --- | --- |
| `PCI.enumerate()` | Scan all bus/device/function combinations |
| `PCI.findDevice(vendorId, deviceId)` | Find device by PCI IDs (returns index or -1) |
| `PCI.findByClass(classCode, subclass)` | Find device by class |
| `PCI.readConfig(bus, dev, fn, reg)` | Read 32-bit PCI config register |
| `PCI.writeConfig(bus, dev, fn, reg, val)` | Write 32-bit PCI config register |
| `PCI.readBAR(bus, dev, fn, barIndex)` | Read Base Address Register (64-bit result) |
| `PCI.enableBusMaster(bus, dev, fn)` | Enable I/O, Memory Space, and Bus Master |
| `PCI.getDevice(index)` | Get a PciDevice struct by index |

The `PciDevice` struct stores: bus, device, function, vendorId, deviceId, classCode, subclass, progIf, headerType, irqLine, and bar0–bar5.

## **21.3 E1000 Network Driver**

The Intel E1000 NIC driver (`kernel/drivers/e1000.lx`) supports the Intel 82540EM as emulated by QEMU (PCI vendor 0x8086, device 0x100E).

### Hardware Interface

The driver uses memory-mapped I/O (MMIO) via BAR0 for register access. The MMIO region is identity-mapped into the kernel's virtual address space. TX and RX use descriptor ring buffers (32 entries each, 16 bytes per descriptor) with 2048-byte packet buffers.

| Function | Description |
| --- | --- |
| `E1000.init()` | PCI discovery, device reset, MAC read, RX/TX setup, link up |
| `E1000.isPresent()` | Returns true if an E1000 NIC was detected |
| `E1000.sendPacket(data, length)` | Transmit a raw Ethernet frame |
| `E1000.poll()` | Check for received packets (call periodically) |
| `E1000.hasPacket()` | Returns true if packets are available |
| `E1000.receivePacket()` | Dequeue the next received packet |
| `E1000.getLastPacketLen()` | Length of the most recently dequeued packet |
| `E1000.getMac(index)` | Get a byte of the MAC address (0–5) |

### QEMU Network Configuration

    -netdev user,id=net0 -device e1000,netdev=net0

QEMU user-mode networking provides a virtual network at 10.0.2.0/24 with gateway 10.0.2.2 and DNS 10.0.2.3.

## **21.4 Network Stack**

The network stack (`kernel/drivers/net.lx`) implements the full TCP/IP suite on top of the E1000 driver.

### Protocol Layers

| Layer | Implementation |
| --- | --- |
| Ethernet | Frame parsing and construction, MAC addressing |
| ARP | Address resolution with 32-entry cache |
| IPv4 | Packet construction with header checksum |
| ICMP | Echo reply (responds to ping requests) |
| UDP | Stateless datagram send/receive |
| TCP | Connection-oriented with SYN/ACK handshake, FIN teardown |
| DNS | A-record resolution over UDP |
| DHCP | Automatic IP configuration with static fallback |

### Network API

| Function | Description |
| --- | --- |
| `Net.init()` | Allocate buffers and initialize state |
| `Net.dhcp()` | Attempt DHCP; fall back to static 10.0.2.15 |
| `Net.configure(ip, subnet, gw, dns)` | Set static IP configuration |
| `Net.isConfigured()` | Returns true if network has an IP address |
| `Net.getIPString()` | Returns current IP as a dotted-decimal string |
| `Net.dnsResolve(hostname)` | Resolve hostname to IPv4 via DNS |
| `Net.sendUDP(dstIP, dstPort, srcPort, data, len)` | Send a UDP datagram |
| `Net.tcpConnect(remoteIP, port)` | Open a TCP connection |
| `Net.tcpSend(data, len)` | Send data over an open TCP connection |
| `Net.tcpReceive(buffer, maxLen, timeoutMs)` | Receive data (blocking with timeout) |
| `Net.tcpClose()` | Gracefully close the TCP connection |
| `Net.processIncoming()` | Poll and dispatch received packets |

### Shell Networking Commands

| Command | Description |
| --- | --- |
| `ifconfig` | Display network interface status, IP, and MAC address |
| `ping <host>` | Send ICMP-equivalent probes to a host |
| `nslookup <hostname>` | Resolve a hostname via DNS |
| `wget <url>` | Download a file via HTTP (http:// only) |

### IP Address Format

All IP addresses in the kernel are stored as 32-bit integers in network byte order (big-endian). The utility functions `makeIP(a, b, c, d)` and `ipToString(ip)` convert between dotted-decimal strings and the internal format.


# **Appendix A: Operator Precedence Table**

Complete precedence reference. Higher level = evaluated first. Use parentheses to override.

|     |     |     |     |
| --- | --- | --- | --- |
| **Level** | **Operators** | **Description** | **Associativity** |
| 1   | . \[\] () | Member access, subscript, call | Left-to-right |
| 2   | ! - ++ -- .random (type) | Unary, cast | Right-to-left |
| 3   | \* / % | Multiplicative | Left-to-right |
| 4   | \+ - | Additive | Left-to-right |
| 5   | &lt; &gt; &lt;= &gt;= | Relational | Left-to-right |
| 6   | \=num= =word= == != | Equality and semantic | Left-to-right |
| 7   | && \| butnot | Logical | Left-to-right |
| 8   | \= += -= \*= /= new_type= | Assignment, re-type | Right-to-left |

# **Appendix B: Reserved Keywords**

The following 38 identifiers are reserved by the Flux language and cannot be used as variable, function, or class names.

|     |     |     |     |
| --- | --- | --- | --- |
|     |     |     |     |
| atomic | func | null | switch |
| bool | if  | panic | thread |
| break | implements | private | true |
| butnot | import | public | try |
| byte | int | return | unsafe |
| catch | interface | struct | void |
| char | long | string | while |
| class | mutex | super | new_type |
| cleanup | new | enum | do  |
| const | exec | export | extends |
| continue | else | elif | float |
| default | false | for | in  |

# **Appendix C: Primitive Type Reference**

Complete reference for all built-in primitive types.

|     |     |     |     |     |
| --- | --- | --- | --- | --- |
| **Type** | **Size** | **Default** | **Range** | **Example Literal** |
| void | 0   | null | null only | void x = null; |
| bool | 1 B | false | true / false | bool flag = true; |
| char | 1 B | \\0 | 0–127 (ASCII) | char c = 'A'; |
| byte | 1 B | 0   | 0 to 255 | byte b = 0xFF; |
| int | 4 B | 0   | \-2,147,483,648 to 2,147,483,647 | int n = 42; |
| long | 8 B | 0   | \-9.2e18 to 9.2e18 | long l = 9999999L; |
| float | 8 B | 0.0 | IEEE 754 double precision | float f = 3.14; |
| string | dynamic | ""  | UTF-8, any length | string s = "Hi"; |
| vec2 | 16 B | (0,0) | Two floats: x, y | vec2 v = vec2(1,2); |
| vec3 | 24 B | (0,0,0) | Three floats: x, y, z | vec3 v = vec3(1,2,3); |
| mat4 | 128 B | identity | 4x4 float matrix | mat4.identity() |
| color32 | 4 B | 0x000000FF | 32-bit RGBA value | color32 c = 0xFF0000FF; |

Flux Language Reference Manual v0.1

_"From the Void, Structure."_