# WGPU Odin Bindings

Bindings to [wgpu-native](https://github.com/gfx-rs/wgpu-native) **22.1.0.5** made by hand in the [Odin programming language](https://odin-lang.org/).

See [examples here](./examples).

## Status

> **Note**
>
> The wgpu-API still in the "Working Draft" phase. Until the specification is stabilized, break changes can happen without notice.

## Bindings only

You can use the bindings only where the procedures are called directly from the `foreign` block. There is also the official bindings in case you want a "raw" version with some helper procedures.

## Wrapper (🚧WIP)

The wrapper version exposes an API similar to the [Rust API](https://docs.rs/wgpu/latest/wgpu/), this allows developers to easily translate Rust tutorials and examples into Odin code.

## Linking

To make this repository easy to maintain and light to download, I decided to not include all binaries files (that can exceed 130MB). You can build the library yourself, but all those files are autogenerated and you can download on wgpu-native releases page:

<https://github.com/gfx-rs/wgpu-native/releases/tag/v22.1.0.5>

**Make sure to match the version tag** is the same from upstream, just place the corresponding files according to the bindings tree in `bindings/lib/`:

```text
📦lib
 ┣ 📂linux
 ┃ ┣ 📂arch64
 ┃ ┃ ┗ 📜libwgpu_native.a
 ┃ ┗ 📂x86_64
 ┃ ┃ ┗ 📜libwgpu_native.a
 ┣ 📂mac_os
 ┃ ┣ 📂arch64
 ┃ ┃ ┗ 📜libwgpu_native.a
 ┃ ┗ 📂x86_64
 ┃ ┃ ┗ 📜libwgpu_native.a
 ┣ 📂windows
 ┃ ┣ 📂i686
 ┃ ┃ ┃ 📜wgpu_native.dll.lib
 ┃ ┃ ┗ 📜wgpu_native.lib
 ┃ ┗ 📂x86_64
 ┃ ┃ ┃ 📜wgpu_native.dll.lib
 ┃ ┃ ┗ 📜wgpu_native.lib
```

Check the foreign import in the file [bindings.odin](./bindings/bindings.odin) for more details. For example, download `wgpu-windows-x86_64-release.zip` and copy `wgpu_native.dll.lib` to the folder `bindings/lib/windows/x86_64/`.

On Windows the linking is dynamic by default, you need `wgpu_native.dll` along side your executable. To build statically, set the config `WGPU_SHARED` to `false` (this option only affects Windows).

Both Linux and Mac by default are statically linked for ease of use, but you can link against system.

### Link against system

On Linux or Mac, you can tell the library to link against system `libwgpu_native` instead of one provided in the directory by defining the Odin config value `WGPU_USE_SYSTEM_LIBRARIES` as `true`.

## Quick Start Guide

1. Clone this repository or [download the zip](https://github.com/Capati/wgpu-odin/archive/refs/heads/main.zip) file.

2. Ensure you follow the "Linking" steps outlined above to include the appropriate binaries for your target platform.

3. Create a folder named `libs/wgpu` in the root of your project (where you run `odin build` from). Alternatively, you can use the `shared` folder in your Odin installation to define a collection.

4. If you want the wrapper version:
    - Copy the `bindings`, `wrapper`, and `utils` folders from this repository to the directory created in step 3.

5. To easily import the package into your project, set up a `collection`:

    ```shell
    // Example of setting up a collection (add this to your build command or script)
    odin build ./src -collection:libs=./libs
    ```

6. You can now import the package in your code:

```odin
import wgpu "libs:wgpu/wrapper"
```

Or

```odin
import wgpu "libs:wgpu/bindings"
```

## Naming Conventions

Types and values follow the [Odin Naming Convention](https://github.com/odin-lang/Odin/wiki/Naming-Convention). In general, `Ada_Case` for types and `snake_case` for values

|                    | Case                                |
| ------------------ | ----------------------------------- |
| Import Name        | snake_case (but prefer single word) |
| Types              | Ada_Case                            |
| Enum Values        | Ada_Case                            |
| Procedures         | snake_case                          |
| Local Variables    | snake_case                          |
| Constant Variables | SCREAMING_SNAKE_CASE                |

## License

MIT license.
