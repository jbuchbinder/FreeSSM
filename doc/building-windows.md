# Building FreeSSM for Windows (64-bit and 32-bit)

## Which bitness do I want?

A 32-bit `FreeSSM.exe` runs perfectly on 64-bit Windows. The bitness only matters
for **J2534 pass-through interfaces**: `FreeSSM.exe` loads the vendor's J2534 DLL
into its own process, and a 64-bit process cannot load a 32-bit DLL.

| Interface type                                   | Recommended build |
|--------------------------------------------------|-------------------|
| USB-serial / K-line cable (SSM1, SSM2)           | 64-bit            |
| ELM327-style (AT commands over a COM port)       | 64-bit            |
| J2534 pass-through (Tactrix OpenPort 2.0, ...)   | **32-bit** - vendors almost always ship a 32-bit DLL only (e.g. `op20pt32.dll`) |

## CI builds (no local toolchain)

`.github/workflows/build-windows.yml` builds and packages FreeSSM on GitHub's
Windows runners.

* Every push builds the **64-bit** package.
* The **32-bit** package is opt-in: Actions -> "Build Windows" -> "Run workflow"
  -> tick *"Also build 32-bit x86"*.

Download the result from the run's *Artifacts* section. The zip is a complete,
self-contained folder - unzip anywhere and run `FreeSSM.exe`, no installer and no
Qt installation needed.

## Building locally with MSYS2 (64-bit)

1. Install [MSYS2](https://www.msys2.org/).
2. Open the **MSYS2 MINGW64** shell and install the toolchain:

```bash
pacman -Syu
pacman -S --needed mingw-w64-x86_64-toolchain mingw-w64-x86_64-qt5-base mingw-w64-x86_64-qt5-tools mingw-w64-x86_64-make git
```

3. Build:

```bash
git clone https://github.com/Comer352L/FreeSSM.git
cd FreeSSM
qmake FreeSSM.pro
make -j$(nproc) release
lrelease FreeSSM.pro
```

4. `FreeSSM.exe` is written to the source directory. To run it outside the MSYS2
   shell, copy the Qt and MinGW DLLs next to it:

```bash
windeployqt --release --no-translations FreeSSM.exe
```

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
