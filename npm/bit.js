// The MoonBit CLI payload is an ES module (moonc emits `import` statements
// for its `#module("node:fs")` FFI bindings); importing it runs the CLI.
export * from "./bit.mjs";
