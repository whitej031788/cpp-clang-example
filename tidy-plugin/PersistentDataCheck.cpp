#include "PersistentDataCheck.h"

#include "clang/AST/ASTContext.h"

using namespace clang;
using namespace clang::ast_matchers;
using namespace clang::tidy;

// This is a simple intra-procedural clang-tidy check
// This is meant to mimic Hexagon SettingPersistentDataCheck
// If a function contains an assignment to an expression whose printed form
// contains "m_pJPersistentObjectData->" but there is no prior call in the same
// function to Update(...) or UpdateNoRecompute(...), flag it.

namespace {
	struct MatchIds {
		static constexpr llvm::StringLiteral kFunc{"func"};
		static constexpr llvm::StringLiteral kAssign{"assign"};
		static constexpr llvm::StringLiteral kUpdate{"update"};
		static constexpr llvm::StringLiteral kUpdateNoReco{"updateNoReco"};
	};
}

PersistentDataCheck::PersistentDataCheck(StringRef Name, ClangTidyContext *Context)
	: ClangTidyCheck(Name, Context) {}

void PersistentDataCheck::registerMatchers(MatchFinder *Finder) {
	if (!getLangOpts().CPlusPlus)
		return;
	// We register multiple matchers and will reconcile in check(...):
	// 1) any function definition
	// 2) any assignment within it
	// 3) any call to Update / UpdateNoRecompute within it
	Finder->addMatcher(
		functionDecl(isDefinition(), unless(isExpansionInSystemHeader())).bind(MatchIds::kFunc), this);

	// assignment expressions
	Finder->addMatcher(
		binaryOperator(isAssignmentOperator(), hasAncestor(functionDecl(isDefinition()).bind(MatchIds::kFunc)))
			.bind(MatchIds::kAssign),
		this);

	// calls to Update / UpdateNoRecompute
	Finder->addMatcher(
		callExpr(callee(functionDecl(hasAnyName("::Update", "::UpdateNoRecompute"))),
			hasAncestor(functionDecl(isDefinition()).bind(MatchIds::kFunc)))
			.bind(MatchIds::kUpdate),
		this);
}

void PersistentDataCheck::check(const MatchFinder::MatchResult &Result) {
	// We need to know, per-function, whether an Update-like call was seen earlier.
	// ClangTidyCheck provides an options store we can abuse per run, but instead
	// we implement a simple approach: if we see an assignment and we cannot find
	// any Update/UpdateNoRecompute in the same function body, we warn.
	if (const auto *Assign = Result.Nodes.getNodeAs<BinaryOperator>(MatchIds::kAssign)) {
		const auto *Func = Result.Nodes.getNodeAs<FunctionDecl>(MatchIds::kFunc);
		if (!Func || !Func->hasBody()) return;

		// Look for any Update/UpdateNoRecompute calls in the function body
		bool hasUpdate = false;
		for (const Stmt *S : Func->getBody()->children()) {
			if (!S) continue;
			for (const Stmt *Sub : S->children()) {
				(void)Sub;
			}
		}
		// Use a recursive matcher on the function body for simplicity
		auto AnyUpdate =
			match(callExpr(callee(functionDecl(hasAnyName("::Update", "::UpdateNoRecompute")))).bind("u"),
				*Func->getBody(), *Result.Context);
		hasUpdate = !AnyUpdate.empty();

		// If no update-like call in this function, inspect the assignment text and look for the pattern
		if (!hasUpdate) {
			// Print LHS of the assignment
			const Expr *LHS = Assign->getLHS()->IgnoreParenImpCasts();
			std::string LHSStr;
			llvm::raw_string_ostream OS(LHSStr);
			LHS->printPretty(OS, nullptr, Result.Context->getPrintingPolicy());
			OS.flush();

			if (LHSStr.find("m_pJPersistentObjectData->") != std::string::npos ||
				LHSStr.find("m_pJPersistentObjectData ->") != std::string::npos) {
				diag(Assign->getBeginLoc(),
					"setting Persistent Data without a prior Update/UpdateNoRecompute in this function");
			}
		}
	}
} 