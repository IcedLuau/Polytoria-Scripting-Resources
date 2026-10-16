# Movement
A Luau reimplementation of the C# movement system. It's built to have at least 90% parity with the C# version.
External velocity is disregarded, as the C# implementation had bugs.

# Setup
1. Set `MovementMode` to Scripted in PlayerDefaults.
2. Put `init.luau` under anything, as a **client script**, and name it appropriately.

## AI Usage:
14 lines or so? Used to help fix climbing, and port the C# math to Luau. (I haven't learnt Vectors in school yet...)
