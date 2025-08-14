#include "CallPairCheck.h"

#include "clang-tidy/ClangTidy.h"
#include "clang/AST/ASTContext.h"
#include "clang/ASTMatchers/ASTMatchFinder.h"

using namespace clang;
using namespace clang::ast_matchers;
using namespace clang::tidy;

CallPairCheck::CallPairCheck(StringRef Name, ClangTidyContext *Context)
	: ClangTidyCheck(Name, Context) {}

void CallPairCheck::registerMatchers(MatchFinder *Finder) {
	if (!getLangOpts().CPlusPlus && !getLangOpts().C99)
		return;
	// Flag functions that call fopen but do not call fclose anywhere in the body.
	Finder->addMatcher(
		functionDecl(
			isDefinition(),
			unless(isExpansionInSystemHeader()),
			hasDescendant(callExpr(callee(functionDecl(hasName("::fopen")))).bind("call")),
			unless(hasDescendant(callExpr(callee(functionDecl(hasName("::fclose"))))))
		).bind("func"),
		this);
}

void CallPairCheck::check(const MatchFinder::MatchResult &Result) {
	const auto *Func = Result.Nodes.getNodeAs<FunctionDecl>("func");
	const auto *Call = Result.Nodes.getNodeAs<CallExpr>("call");
	if (!Func || !Call)
		return;
	diag(Call->getBeginLoc(),
		"function '%0' calls fopen but does not call fclose; potential resource leak")
		<< Func->getNameInfo().getName();
} 