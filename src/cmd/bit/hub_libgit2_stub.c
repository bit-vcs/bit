#include <dlfcn.h>
#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct git_repository git_repository;
typedef struct git_reference git_reference;

static void *hub_libgit2_handle = NULL;
static int hub_libgit2_initialized = 0;

static int (*git_libgit2_init_ptr)(void) = NULL;
static int (*git_repository_open_ptr)(git_repository **out, const char *path) = NULL;
static void (*git_repository_free_ptr)(git_repository *repo) = NULL;
static const char *(*git_repository_path_ptr)(const git_repository *repo) = NULL;
static int (*git_repository_head_ptr)(git_reference **out, git_repository *repo) = NULL;
static void (*git_reference_free_ptr)(git_reference *ref) = NULL;
static const char *(*git_reference_name_ptr)(const git_reference *ref) = NULL;

static char *hub_libgit2_bytes_to_cstring(moonbit_bytes_t bytes) {
    int32_t len = Moonbit_array_length(bytes);
    char *str = (char *)malloc((size_t)len + 1);
    if (str == NULL) {
        return NULL;
    }
    memcpy(str, bytes, (size_t)len);
    str[len] = '\0';
    return str;
}

static moonbit_bytes_t hub_libgit2_cstring_to_bytes(const char *str) {
    if (str == NULL) {
        return moonbit_make_bytes(0, 0);
    }
    size_t len = strlen(str);
    moonbit_bytes_t result = moonbit_make_bytes((int32_t)len, 0);
    memcpy(result, str, len);
    return result;
}

static int hub_libgit2_load_library(void) {
    if (hub_libgit2_handle != NULL) {
        return 0;
    }

#ifdef __MACH__
    const char *paths[] = {
        "libgit2.dylib",
        "/usr/local/lib/libgit2.dylib",
        "/opt/homebrew/lib/libgit2.dylib",
        "/usr/local/Cellar/libgit2/1.9.1/lib/libgit2.dylib",
        "/opt/homebrew/Cellar/libgit2/1.9.1/lib/libgit2.dylib",
        NULL
    };
#else
    const char *paths[] = {
        "libgit2.so.1.9",
        "libgit2.so.1",
        "libgit2.so",
        "/usr/lib/libgit2.so",
        "/usr/local/lib/libgit2.so",
        NULL
    };
#endif

    for (int i = 0; paths[i] != NULL; i++) {
        hub_libgit2_handle = dlopen(paths[i], RTLD_LAZY);
        if (hub_libgit2_handle != NULL) {
            break;
        }
    }

    if (hub_libgit2_handle == NULL) {
        return -1;
    }

    git_libgit2_init_ptr = dlsym(hub_libgit2_handle, "git_libgit2_init");
    git_repository_open_ptr = dlsym(hub_libgit2_handle, "git_repository_open");
    git_repository_free_ptr = dlsym(hub_libgit2_handle, "git_repository_free");
    git_repository_path_ptr = dlsym(hub_libgit2_handle, "git_repository_path");
    git_repository_head_ptr = dlsym(hub_libgit2_handle, "git_repository_head");
    git_reference_free_ptr = dlsym(hub_libgit2_handle, "git_reference_free");
    git_reference_name_ptr = dlsym(hub_libgit2_handle, "git_reference_name");

    if (git_libgit2_init_ptr == NULL ||
        git_repository_open_ptr == NULL ||
        git_repository_free_ptr == NULL ||
        git_repository_path_ptr == NULL ||
        git_repository_head_ptr == NULL ||
        git_reference_free_ptr == NULL ||
        git_reference_name_ptr == NULL) {
        dlclose(hub_libgit2_handle);
        hub_libgit2_handle = NULL;
        return -2;
    }

    return 0;
}

int32_t hub_libgit2_init(void) {
    int err = hub_libgit2_load_library();
    if (err != 0) {
        return err;
    }
    if (!hub_libgit2_initialized) {
        int rc = git_libgit2_init_ptr();
        if (rc < 0) {
            return rc;
        }
        hub_libgit2_initialized = 1;
    }
    return 0;
}

int32_t hub_libgit2_is_loaded(void) {
    return hub_libgit2_handle != NULL ? 1 : 0;
}

static git_repository *hub_libgit2_open_repo(moonbit_bytes_t path) {
    if (hub_libgit2_init() != 0) {
        return NULL;
    }
    char *path_str = hub_libgit2_bytes_to_cstring(path);
    if (path_str == NULL) {
        return NULL;
    }
    git_repository *repo = NULL;
    int err = git_repository_open_ptr(&repo, path_str);
    free(path_str);
    if (err != 0) {
        return NULL;
    }
    return repo;
}

moonbit_bytes_t hub_libgit2_repo_path(moonbit_bytes_t path) {
    git_repository *repo = hub_libgit2_open_repo(path);
    if (repo == NULL) {
        return moonbit_make_bytes(0, 0);
    }
    moonbit_bytes_t result = hub_libgit2_cstring_to_bytes(
        git_repository_path_ptr(repo)
    );
    git_repository_free_ptr(repo);
    return result;
}

moonbit_bytes_t hub_libgit2_head_name(moonbit_bytes_t path) {
    git_repository *repo = hub_libgit2_open_repo(path);
    if (repo == NULL) {
        return moonbit_make_bytes(0, 0);
    }
    git_reference *ref = NULL;
    int err = git_repository_head_ptr(&ref, repo);
    moonbit_bytes_t result = moonbit_make_bytes(0, 0);
    if (err == 0 && ref != NULL) {
        result = hub_libgit2_cstring_to_bytes(git_reference_name_ptr(ref));
        git_reference_free_ptr(ref);
    }
    git_repository_free_ptr(repo);
    return result;
}
