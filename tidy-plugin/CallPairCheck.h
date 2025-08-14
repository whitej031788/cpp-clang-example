#pragma once

#include "clang-tidy/ClangTidyCheck.h"
#include "clang/ASTMatchers/ASTMatchFinder.h"

class CallPairCheck : public clang::tidy::ClangTidyCheck {
public:
	CallPairCheck(llvm::StringRef Name, clang::tidy::ClangTidyContext *Context);
	void registerMatchers(clang::ast_matchers::MatchFinder *Finder) override;
	void check(const clang::ast_matchers::MatchFinder::MatchResult &Result) override;
}; 