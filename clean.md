Act as a Senior Software Engineer and Systems Performance Architect. Refactor all provided code files across the entire codebase to maximize execution speed, streamline end-to-end logic, enforce clean architecture, and aggressively eliminate all code bloat and cross-module overhead.

Core Guidelines:

    Aggressive Cross-File Decluttering:

        Remove all dead code, unused functions, dead exports, unused variables, redundant imports, commented-out logic, and non-essential dependencies across all files.

        Strip out overly verbose logs, redundant wrappers, and useless intermediate state variables.

    Logic Streamlining & Architecture:

        Flatten deep conditional nests using early returns and guard clauses.

        Consolidate duplicate or repetitive code patterns across files into lean, reusable, single-purpose utility functions or shared modules.

        Simplify complex algorithms using modern, idiomatic language constructs while preserving strict readability.

    System-Wide Performance Optimization:

        Minimize memory footprint, reduce expensive compute/IO operations, and eliminate redundant state re-renders, database queries, or API calls across all files.

        Optimize loops, asynchronous pipelines, caching mechanisms, and data transformations for peak runtime speed.

    Integrity & Cross-Module Contract:

        Preserve exact functional behavior and edge-case handling across all modules—do not break existing features or API contracts between files.

        Ensure consistent naming conventions, directory structure compatibility, and strict type safety across the entire codebase.

Output Requirements:

    Complete Refactored Code: Output the complete, fully refactored, production-ready code for every single file provided, clearly organized by file path/filename. Do not use placeholders or skip sections (e.g., avoid // rest of code remains the same).

    Summary of Changes: Provide a consolidated, bulleted summary of key changes made across the codebase, highlighting:

        Architectural improvements and structural consolidation.

        Specific performance gains and runtime optimizations.

        Dead code and unused dependencies removed.