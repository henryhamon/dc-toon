 [![Gitter](https://img.shields.io/badge/Available%20on-Intersystems%20Open%20Exchange-00b2a9.svg)](https://openexchange.intersystems.com/package/intersystems-iris-dev-template)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat&logo=AdGuard)](LICENSE)

# dc-toon – TOON for InterSystems IRIS

## 📖 Overview

**dc-toon** is a lightweight, production-ready implementation of **TOON (Token-Oriented Object Notation)** for **InterSystems IRIS ObjectScript**.  
It brings the benefits of the TOON format—originally designed for Python and TypeScript—to IRIS, enabling you to serialize structured data more compactly than JSON and dramatically reduce LLM token usage in AI workflows.

This project is especially useful for:

- RAG pipelines where large JSON payloads inflate prompt size.
- Agentic workflows (LangGraph, custom orchestrators) that pass rich state between tools.

dc-toon currently provides:

- `dc.toon.Converter` – TOON encoder/decoder for `%DynamicObject` / `%DynamicArray`.
- `dc.toon.Parser` – TOON → JSON parser used internally by the converter.

***

## 🎯 Motivation

Large JSON structures are expensive to send to LLMs. Even when you compress content semantically, the **structural overhead** (braces, brackets, quotes, repeated keys) still consumes a lot of tokens. TOON was created to address exactly this:  
a **human-readable, LLM-friendly, token-efficient** representation of structured data.

This port brings that same idea to the InterSystems IRIS ecosystem:

- Replace verbose JSON with compact TOON when sending context to LLMs.
- Maintain clear structure (objects, primitive arrays, tabular arrays).
- Keep everything native: `%DynamicObject`, `%DynamicArray`, ObjectScript.

Typical savings in this implementation are around **30–50% fewer characters** for the same payload, which translates directly into **lower token usage and cost** in LLM prompts.

***

## ⚙️ How It Works

At the core of dc-toon are two classes:

### `dc.toon.Converter`

This is the main entry point. It knows how to:

- **Encode** IRIS dynamic structures to TOON:
  - Objects → `key: value` lines with indentation.
  - Primitive arrays → `[N]: v1,v2,v3`.
  - Tabular arrays of objects → `[N,]{field1,field2}:\n  v1,v2\n  v3,v4`.
  - Mixed arrays → `[N]:\n- item1\n- item2`.

- **Decode** TOON back into `%DynamicObject` / `%DynamicArray` using the parser.

Key class methods:

```objectscript
/// Encode IRIS dynamic value to TOON
ClassMethod ToTOON(input As %DynamicAbstractObject, options As %DynamicObject = "") As %String

/// Decode TOON string back into a dynamic value
ClassMethod FromTOON(toonStr As %String, options As %DynamicObject = "", Output result) As %Status
```

Encoding options are provided via a `%DynamicObject`:

- `indent` – spaces per indentation level (default: 2).
- `delimiter` – `"," | "pipe" | "tab"` (default: comma).
- `lengthMarker` – `"#"` to enable markers like `[3]`, or `""` (default).

Example (primitive array with pipe delimiter):

```objectscript
Set data = ##class(%DynamicArray).%New()
Do data.%Push(1), data.%Push(2), data.%Push(3)

Set opts = ##class(%DynamicObject).%New()
Do opts.%Set("delimiter","pipe")

Set toon = ##class(dc.toon.Converter).ToTOON(data, opts)
// [3|]: 1|2|3
```

### `dc.toon.Parser`

The parser is responsible for TOON → JSON semantics:

- Interprets headers like `[N]`, `[N,]{...}`, `[N|]:`.
- Splits rows, fields, and mixed lists.
- Reconstructs `%DynamicArray` and `%DynamicObject` instances.
- Supports a `strict` option for length validation and basic syntax checks.

You typically don’t call `dc.toon.Parser` directly – it is used internally by `dc.toon.Converter.FromTOON()`.

***

## 🧪 Test Suite

The project includes a comprehensive `%UnitTest` suite in  
`dc.toon.unittests.TestToon`, covering:

- Simple object encoding.
- Primitive array encoding/decoding.
- Tabular array encoding/decoding.
- Nested objects with indentation.
- Delimiter handling (comma, pipe).
- Length markers `[#N]`.
- Quoting behavior for special strings.
- Round-trip encode → decode.
- Token savings vs JSON for realistic payloads.


To run the unit tests we can use the Package Manager environment.

```objectscript
zpm
dc-toon test -v
```

You should see **All PASSED** 


***

## 🚀 Installation with IPM

```
zpm:USER>install dc-toon
```

## 🛠️ Installation with Docker

The backend is containerized for easy setup. Follow these steps to get it running.

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/henryhamon/dc-toon.git](https://github.com/henryhamon/dc-toon.git)
    cd dc-toon
    ```

2.  **Build the Docker container:**
    This command builds the necessary images for the application. The `--no-cache` flag ensures you are building from the latest source.
    ```bash
    docker-compose build --no-cache --progress=plain
    ```

3.  **Start the application:**
    This command starts the services in detached mode (`-d`).
    ```bash
    docker-compose up -d
    ```

4.  **Stop and remove containers (when done):**
    To stop the application and remove all associated containers, networks, and volumes.
    ```bash
    docker-compose down --rmi all
    ```

***

## 💡 Usage Examples

### Encode a Simple Object

```objectscript
Set obj = {"name":"Alice","age":30}
Set toon = ##class(dc.toon.Converter).ToTOON(obj)

// name: Alice
// age: 30
```

### Encode a Tabular Array

```objectscript
Set users = ##class(%DynamicArray).%New()
Do users.%Push({"id":1,"name":"Alice","age":30})
Do users.%Push({"id":2,"name":"Bob","age":25})

Set toon = ##class(dc.toon.Converter).ToTOON(users)

// [2,]{id,name,age}:
//   1,Alice,30
//   2,Bob,25
```

### Decode Back from TOON

```objectscript
Set toonStr = "[2,]{id,name}:"_$Char(10)_"  1,Alice"_$Char(10)_"  2,Bob"
Set status = ##class(dc.toon.Converter).FromTOON(toonStr,, .result)
// result is a %DynamicArray of %DynamicObject
```

***

## 🔍 Limitations 

- IRIS does not have a native `null` type; empty values are represented using `""`.  
  dc-toon maps empty / undefined values to the literal `null` in TOON where appropriate.
- Boolean values in IRIS are typically `0` / `1`. The current implementation focuses on correctness and compactness rather than adding a distinct boolean type.

***

## 🙌 Credits

- Original TOON idea and Python implementations:
  - [xaviviro/python-toon (reference and inspiration for behavior/format).](https://github.com/xaviviro/python-toon)

> dc-toon is developed with ❤️ by 
> [Henry Pereira](https://community.intersystems.com/user/henry-pereira)