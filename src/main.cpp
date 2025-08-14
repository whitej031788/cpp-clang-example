#include <iostream>
#include <cstdio>

// Intentionally minimal: fopen without fclose (resource leak)
void file_leak() {
    FILE *f = fopen("/etc/hosts", "r");
    if (f) {
        char buf[16];
        (void)fgets(buf, sizeof(buf), f);
        // Missing fclose(f);
    }
}

// Stubs to model the API in the custom checker
void Update() {}
void UpdateNoRecompute() {}

struct PersistentObjectData { int foo; };
struct PersistentHolder {
    PersistentObjectData *m_pJPersistentObjectData;
};

void persistent_violation(PersistentHolder *h, int v) {
    // No Update() called in this function before setting persistent data
    h->m_pJPersistentObjectData->foo = v; // should trigger example-persistent-data-check
}

int main() {
    file_leak();
    PersistentObjectData pod{0};
    PersistentHolder h{&pod};
    persistent_violation(&h, 42);
    std::cout << "done\n";
    return 0;
} 