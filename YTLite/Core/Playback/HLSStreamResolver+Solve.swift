import Foundation
import JavaScriptCore

// MARK: - n-signature solving

extension HLSStreamResolver {
    static var solverBridge: String {
        "var meriyah = (typeof lib !== 'undefined' && lib.meriyah)"
            + " || undefined; var astring = (typeof lib !== 'undefined'"
            + " && lib.astring) || undefined;"
    }

    static var solverWrapper: String {
        """
        function __ytSolveN(playerText, n) {
          try {
            var r = jsc({
              type: 'player', player: playerText,
              requests: [{ type: 'n', challenges: [n] }]
            });
            if (r && r.responses && r.responses[0]
              && r.responses[0].data) {
              var s = r.responses[0].data[n];
              return (typeof s === 'string' && s !== n) ? s : '';
            }
          } catch (e) { return 'ERR:' + e; }
          return '';
        }
        """
    }

    static func playerJSURL(_ jsPath: String) -> URL? {
        if jsPath.hasPrefix("http") {
            return URL(string: jsPath)
        }
        return URL(string: "https://www.youtube.com" + jsPath)
    }

    /// Solves the n-throttling signature. Results are memoized per
    /// (player JS, n) — repeated values skip solving entirely. Tries the
    /// on-device JSContext solver (iOS 14+) first, then falls back to the
    /// remote solver (required on iOS 12/13, where base.js ES2020 syntax
    /// cannot be parsed on-device).
    func solveN(
        unsolved: String,
        jsPath: String?,
        completion: @escaping (String?) -> Void
    ) {
        let cacheKey = "\(jsPath ?? "")|\(unsolved)"
        if let cached = cachedSolvedN(for: cacheKey) {
            AppLog.player("hlsResolve: n cache hit")
            completion(cached)
            return
        }
        solveOnDevice(unsolved: unsolved, jsPath: jsPath) { [weak self] solved in
            if let solved {
                self?.storeSolvedN(solved, for: cacheKey)
                completion(solved)
                return
            }
            self?.solveRemote(unsolved: unsolved, jsPath: jsPath) { solved in
                if let solved {
                    self?.storeSolvedN(solved, for: cacheKey)
                }
                completion(solved)
            }
        }
    }

    private func solveOnDevice(
        unsolved: String,
        jsPath: String?,
        completion: @escaping (String?) -> Void
    ) {
        guard #available(iOS 14.0, *) else {
            AppLog.player("hlsResolve: on-device solve needs iOS 14+")
            completion(nil)
            return
        }
        guard let jsPath, let baseURL = Self.playerJSURL(jsPath) else {
            completion(nil)
            return
        }
        if let cached = cachedPlayerJS(path: jsPath) {
            runSolverAsync(baseJS: cached, unsolved: unsolved, completion: completion)
            return
        }
        fetchText(url: baseURL) { [weak self] result in
            guard let self, case let .success(baseJS) = result else {
                completion(nil)
                return
            }
            storePlayerJS(baseJS, path: jsPath)
            runSolverAsync(
                baseJS: baseJS, unsolved: unsolved, completion: completion
            )
        }
    }

    private func runSolverAsync(
        baseJS: String,
        unsolved: String,
        completion: @escaping (String?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            completion(self?.runSolver(baseJS: baseJS, unsolved: unsolved))
        }
    }

    private func runSolver(baseJS: String, unsolved: String) -> String? {
        guard let context = JSContext() else {
            return nil
        }
        context.exceptionHandler = { _, value in
            AppLog.player("hlsResolve: JS exception \(value?.toString() ?? "")")
        }
        context.evaluateScript(WebViewHLSSolverJS.lib)
        context.evaluateScript(Self.solverBridge)
        context.evaluateScript(WebViewHLSSolverJS.core)
        context.evaluateScript(Self.solverWrapper)
        guard let fn = context.objectForKeyedSubscript("__ytSolveN") else {
            return nil
        }
        let value = fn.call(withArguments: [baseJS, unsolved])
        guard let solved = value?.toString(),
              !solved.isEmpty,
              !solved.hasPrefix("ERR:") else {
            if let err = value?.toString(), err.hasPrefix("ERR:") {
                AppLog.player("hlsResolve: solver \(err)")
            }
            return nil
        }
        return solved
    }
}
