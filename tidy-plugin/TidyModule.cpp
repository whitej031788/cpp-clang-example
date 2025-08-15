#include "clang-tidy/ClangTidyModule.h"
#include "clang-tidy/ClangTidyModuleRegistry.h"

#include "CallPairCheck.h"
#include "PersistentDataCheck.h"

using namespace clang;
using namespace clang::tidy;

namespace {

class LeakModule : public ClangTidyModule {
public:
	void addCheckFactories(ClangTidyCheckFactories &Factories) override;
};

} // namespace

void LeakModule::addCheckFactories(ClangTidyCheckFactories &Factories) {
	Factories.registerCheck<CallPairCheck>("example-call-pair-check");
	Factories.registerCheck<PersistentDataCheck>("example-persistent-data-check");
}

static ClangTidyModuleRegistry::Add<LeakModule>
X("example-module", "Example module with simple checks.");

volatile int LeakModuleAnchorSource = 0; 