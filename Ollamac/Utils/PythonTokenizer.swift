//
//  PythonTokenizer.swift
//  Ollamac
//
//  Created by user on 2024-03-07.
//

import Foundation
import PythonKit

var tokenizer: PythonObject? = nil

func configureTokenizerPython(from_pretrained pretrained_model_name_or_path: String? = nil) {
    do {
        // TODO: Rather than rely on system Python, or this hard-coded path,
        //       embed a version of https://github.com/beeware/Python-Apple-support
        let sys = try Python.attemptImport("sys")
        sys.path.append("/Users/user/Development/venv-ollamac/lib/python3.12/site-packages")
        print("Python Version: \(sys.version)")
    } catch {
        print("failed to initialize python")
        return
    }

    do {
        // https://stackoverflow.com/questions/72294775/how-do-i-know-how-much-tokens-a-gpt-3-request-used
        // TODO: Consider `tiktoken` as well
        // TODO: If we're going to embed this, note that we need to pre-run this and download the GPT2 tokenizer files
        // TODO: This should be retained in memory, but we should confirm that it actually is
        let transformers = try Python.attemptImport("transformers")
        
        let os = Python.import("os")
        os.environ["HF_HUB_OFFLINE"] = 1
        
        tokenizer = transformers.GPT2TokenizerFast.from_pretrained(
            pretrained_model_name_or_path ?? "gpt2",
            local_files_first: true)
    } catch {
        print("failed to initialize python tokenizer")
        return
    }
}

func computeTokenCount(_ text: String) -> Int? {
    guard tokenizer != nil else { return nil }

    do {
        let tokens = try tokenizer!(text)["input_ids"]
        return tokens.count
    } catch {
        print("failed to tokenize message text with length \(text.count)")
        return nil
    }
}
