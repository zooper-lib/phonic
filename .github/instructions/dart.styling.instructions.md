---
applyTo: '**/*.dart'
---

# File Ordering (top → bottom)
- library documentation (ONLY when allowed)
- imports (dart: → package: → relative), alphabetical
- exports, alphabetical
- top-level constants
- top-level typedefs, aliases
- top-level public enums
- top-level public classes / mixins / extensions
- top-level private enums
- top-level private classes / mixins / extensions (ALWAYS LAST)

# Class Member Ordering
1. static fields (public → private)
2. instance fields (public → private)
3. constructors (public → named → private)
4. factory constructors
5. public getters
6. public setters
7. public methods
8. operator overloads
9. protected methods
10. private getters / setters
11. private methods
12. static methods (public → private)