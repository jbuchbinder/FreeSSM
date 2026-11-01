# Building FreeSSM for Windows (x86_64, ARM64 and 32-bit)

## Which build do I want?

On Windows 11 on ARM, prefer the **arm64** package: it runs natively instead of
under x86/x64 emulation, which keeps the timing of the half-duplex K-line
communication closer to what the protocol expects.

On ordinary x86 hardware the question is only 32- vs 64-bit:

A 32-bit `FreeSSM.exe` runs perfectly on 64-bit Windows. The bitness only matters
for **J2534 pass-through interfaces**: `FreeSSM.exe` loads the vendor's J2534 DLL
into its own process, and a 64-bit process cannot load a 32-bit DLL.

| Interface type                                   | Recommended build |
|--------------------------------------------------|-------------------|
| USB-serial / K-line cable (SSM1, SSM2)           | 64-bit            |
| ELM327-style (AT commands over a COM port)       | 64-bit            |
| J2534 pass-through (Tactrix OpenPort 2.0, ...)   | **32-bit** - vendors almost always ship a 32-bit DLL only (e.g. `op20pt32.dll`) |

Note that a J2534 interface cannot be used from the arm64 build either: the
vendor DLLs are x86/x64 only.

## CI builds (no local toolchain)

`.github/workflows/build-windows.yml` builds and packages FreeSSM on GitHub's
Windows runners.

* Every push builds the **x86_64** package (MSYS2 `MINGW64`, GCC) and the
  **arm64** package (MSYS2 `CLANGARM64`, clang/libc++, on a `windows-11-arm`
  runner).
* The **32-bit** package is opt-in: Actions -> "Build Windows" -> "Run workflow"
  -> tick *"Also build 32-bit x86"*.

Download the result from the run's *Artifacts* section. The zip is a complete,
self-contained folder - unzip anywhere and run `FreeSSM.exe`, no installer and no
Qt installation needed.

## Building locally with MSYS2 (x86_64 or ARM64)

1. Install [MSYS2](https://www.msys2.org/).
2. Open the **MSYS2 MINGW64** shell (or **CLANGARM64** on an ARM64 machine) and
   install the toolchain:

```bash
pacman -Syu
pacman -S --needed git
pacboy -S --needed toolchain:p qt5-base:p qt5-tools:p make:p
```

   `pacboy`'s `:p` suffix expands to the prefix of whichever environment you are
   in, so the same line works for `MINGW64` and `CLANGARM64`.

3. Build:

```bash
git clone https://github.com/Comer352L/FreeSSM.git
cd FreeSSM
qmake-qt5 FreeSSM.pro
mingw32-make -j$(nproc) release
for ts in FreeSSM_*.ts; do lrelease-qt5 "$ts" -qm "${ts%.ts}.qm"; done
```

> MSYS2 suffixes the Qt5 tools with `-qt5`. Do not run `lrelease FreeSSM.pro`
> with the `.pro` file: lrelease then re-invokes itself through a hardcoded
> `$QT_INSTALL_BINS/lrelease.exe`, which MSYS2 does not install.

4. `FreeSSM.exe` is written to the source directory. To run it outside the MSYS2
   shell, copy the Qt and MinGW DLLs next to it:

```bash
windeployqt-qt5 --release --no-translations --no-angle FreeSSM.exe
```

   `--no-angle` is required: MSYS2 builds Qt5 against desktop OpenGL and ships
   no `libGLESv2.dll`, which windeployqt otherwise treats as a fatal error.

   MSYS2's Qt links third-party libraries (pcre2, harfbuzz, zlib, freetype, ...)
   dynamically and `windeployqt` does not follow those, so also copy every
   remaining import from `/mingw64/bin` - the "Deploy Qt + MinGW runtime" step in
   the CI workflow does this automatically with `objdump -p`.

> `make install` is **not** usable on modern Qt: the `dllstarget` rule in
> `FreeSSM.pro` still copies Qt4/early-Qt5 DLL names (`icudt51.dll`,
> `libgcc_s_dw2-1.dll`, ...) that no longer exist. Use `windeployqt` instead.

## Building locally with the official Qt installer (32-bit)

Install Qt **5.15.2** with the component *MinGW 8.1.0 32-bit* plus the matching
*MinGW 8.1.0* toolchain, then from the "Qt 5.15.2 (MinGW 8.1.0 32-bit)" command
prompt:

```bat
qmake FreeSSM.pro
mingw32-make -j4 release
lrelease FreeSSM.pro
windeployqt --release --compiler-runtime FreeSSM.exe
```

Only the MinGW builds of Qt are supported; the MSVC builds are not.
