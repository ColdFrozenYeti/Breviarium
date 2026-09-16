import Foundation

/// Ports Divinum Officium's `process_conditional_lines()` (`SetupString.pl:378-486`) —
/// the stack machine that resolves inline `(sed ...)` conditionals within a section's
/// body into the final set of lines that apply for a given `ConditionalContext`.
///
/// This is the piece that makes `(sed rubrica 196 aut rubrica 1955 omittuntur)` actually
/// delete the preceding block of text it refers to, or that lets a later `(atque ...)`
/// reopen text an earlier, weaker conditional had suppressed. It only ever runs at
/// render time in `BreviariumKit` with a complete context — see `docs/PLAN.md`'s
/// 2026-09-16 data-pipeline amendment for why this doesn't run inside `BreviariumData`.
public enum ConditionalLineProcessor {

    private enum FrameState { case notYetAffirmative, affirmative, dummyFrame }
    private typealias Frame = (affirmative: FrameState, scope: ConditionalGrammar.Scope)

    /// Resolves a section body's lines against `context`, returning the lines that
    /// survive. Input is typically a section's raw body split on `"\n"`.
    public static func resolve(lines: [String], context: ConditionalContext) -> [String] {
        var output: [String] = []
        var stack: [Frame] = [(.affirmative, .nest)]
        var offsets: [Int] = [-1]    // offsets[strength] = the output-length "fence" for that strength.

        for rawLine in lines {
            var line: Substring = rawLine[...]
            let strippedLine = line.drop(while: { $0 == " " || $0 == "\t" })

            if let (clause, rest) = ConditionalGrammar.matchLeadingClause(in: strippedLine) {
                let conditionHeld = ConditionalEvaluator.evaluate(clause.condition, context: context)
                let parsed = ConditionalGrammar.parseScopeAndStrength(stopwords: clause.stopwords, scopePhrase: clause.scopePhrase)
                let strength = parsed.strength
                let backscope = parsed.backscope
                var forwardscope = parsed.forwardscope
                var result = conditionHeld

                line = rest.drop(while: { $0 == " " || $0 == "\t" })

                let offsetsLastIndex = offsets.count - 1
                let stackLastIndex = stack.count - 1

                if stack[stack.count - 1].affirmative == .affirmative || strength >= offsetsLastIndex {
                    if strength >= offsetsLastIndex {
                        stack = []
                    } else if strength >= offsetsLastIndex - stackLastIndex {
                        setLastIndex(&stack, offsetsLastIndex - strength - 1)
                    }

                    if result {
                        let fence = (offsets.count - 1 >= strength) ? offsets[strength] : -1

                        switch backscope {
                        case .line:
                            if output.count - 1 > fence { output.removeLast() }
                        case .chunk:
                            while output.count - 1 > fence, !isBlankLine(output[output.count - 1]) {
                                output.removeLast()
                            }
                            while output.count - 1 > fence, isBlankLine(output[output.count - 1]) {
                                output.removeLast()
                            }
                        case .nest:
                            setLastIndex(&output, fence)
                        case .null:
                            break
                        }
                    }

                    if forwardscope == .null {
                        forwardscope = .nest
                        result = true
                    }

                    if result {
                        while offsets.count <= strength { offsets.append(-1) }
                        for s in 0...strength { offsets[s] = output.count - 1 }
                    }

                    while strength < (offsets.count - 1) - (stack.count - 1) - 1 {
                        stack.append((.dummyFrame, forwardscope))
                    }

                    stack.append((result ? .affirmative : .notYetAffirmative, forwardscope))
                }

                if line.isEmpty { continue }    // Nothing left on this line to push as content.
            }

            // Strip the line-continuation/merge marker.
            if line.first == "~" { line = line.dropFirst() }
            let lineText = String(line)

            if stack[stack.count - 1].affirmative == .affirmative {
                output.append(lineText)
            }

            // Let single-line/blank-terminated-chunk scopes expire as lines are consumed.
            while stack[stack.count - 1].scope == .line
                || (stack[stack.count - 1].scope == .chunk && isBlankLine(lineText))
            {
                repeat {
                    stack.removeLast()
                } while !stack.isEmpty && stack[stack.count - 1].affirmative == .dummyFrame
                if stack.isEmpty { stack.append((.affirmative, .nest)) }
            }
        }

        return output
    }

    /// Mirrors Perl's `$#array = n` (truncate an array so its last valid index is `n`;
    /// any `n < 0` empties it).
    private static func setLastIndex<T>(_ array: inout [T], _ n: Int) {
        array = n < 0 ? [] : Array(array.prefix(n + 1))
    }

    private static func isBlankLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed == "_"
    }
}
