# Branch mapping investigation

The initial seven unresolved edges target six short functions absent from automatic discovery. Boundaries were inspected in the locally loaded executable image pinned by the documented XEX SHA-256; generated game code and image dumps remain ignored.

| Address | Size | Boundary evidence |
| --- | --- | --- |
| 0x82DC61E0 | 8 | Member-pointer load followed by tail branch; next thunk starts at +8. |
| 0x82DC61F0 | 8 | Member-pointer load followed by tail branch; next thunk starts at +8. |
| 0x82DC6200 | 8 | Member-pointer load followed by tail branch; next thunk starts at +8. |
| 0x82DDCED8 | 20 | Optional-member check with conditional return and final tail branch; following instruction is a separate return stub. |
| 0x8303CC38 | 16 | Vtable assignment and tail branch; next independent thunk starts immediately after. |
| 0x83062898 | 76 | Conditional returns and bounded free-slot search; final return followed by zero padding. |

Mappings use `[entrypoint.functions]` in the v0.10.0 manifest. Root-level `[functions]` is ignored by that manifest parser; the older wiki example refers to the standalone config format.

Once these boundaries are fixed, neighboring thunks become reachable. Additional inspected mappings currently cover 0x82DC61F8, 0x82DC6208, 0x82DC6210, 0x82DCF918, and 0x82DCF920, each eight bytes ending in a tail branch. Validation is being iterated; a clean generation pass is required before calling the branch work complete.

Names describe observed structure only; they do not claim recovered original game symbol names.
