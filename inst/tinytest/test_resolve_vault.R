# Tests for vault path resolution (db.R: resolve_vault, find_vault_walkup)

library(pensar)

# Save and restore ambient resolver state so tests are deterministic
# regardless of the environment the suite runs in.
saved_env <- Sys.getenv("PENSAR_VAULT", unset = NA)
saved_opt <- getOption("pensar.vault", NULL)
on.exit({
    if (is.na(saved_env)) {
        Sys.unsetenv("PENSAR_VAULT")
    } else {
        Sys.setenv(PENSAR_VAULT = saved_env)
    }
    options(pensar.vault = saved_opt)
}, add = TRUE)
Sys.unsetenv("PENSAR_VAULT")
options(pensar.vault = NULL)

resolve_vault <- pensar:::resolve_vault
find_vault_walkup <- pensar:::find_vault_walkup

# --- PENSAR_VAULT wins, source = "env" ---
v_env <- file.path(tempdir(), paste0("vault-env-",
                                     format(Sys.time(), "%H%M%S")))
init_vault(v_env, rproj = FALSE, agent_instructions = FALSE)
Sys.setenv(PENSAR_VAULT = v_env)
r <- resolve_vault(start = tempdir())
expect_equal(r$source, "env")
expect_equal(r$path, normalizePath(v_env))
Sys.unsetenv("PENSAR_VAULT")
unlink(v_env, recursive = TRUE)

# --- Walk-up from inside the vault, source = "walkup" ---
v_walk <- file.path(tempdir(), paste0("vault-walk-",
                                      format(Sys.time(), "%H%M%S")))
init_vault(v_walk, rproj = FALSE, agent_instructions = FALSE)
r <- resolve_vault(start = v_walk)
expect_equal(r$source, "walkup")
expect_equal(r$path, normalizePath(v_walk))

# --- Walk-up from a deep subdir still finds the vault ---
deep <- file.path(v_walk, "wiki")
r <- resolve_vault(start = deep)
expect_equal(r$source, "walkup")
expect_equal(r$path, normalizePath(v_walk))
unlink(v_walk, recursive = TRUE)

# --- Walk-up finds vault/ subdir from project root ---
proj <- file.path(tempdir(), paste0("proj-",
                                    format(Sys.time(), "%H%M%S")))
dir.create(proj)
v_sub <- file.path(proj, "vault")
init_vault(v_sub, rproj = FALSE, agent_instructions = FALSE)
r <- resolve_vault(start = proj)
expect_equal(r$source, "walkup-subdir")
expect_equal(r$path, normalizePath(v_sub))
unlink(proj, recursive = TRUE)

# --- Precedence: dir/schema.md wins over dir/vault/schema.md ---
both <- file.path(tempdir(), paste0("both-",
                                    format(Sys.time(), "%H%M%S")))
init_vault(both, rproj = FALSE, agent_instructions = FALSE)
v_inner <- file.path(both, "vault")
init_vault(v_inner, rproj = FALSE, agent_instructions = FALSE)
r <- resolve_vault(start = both)
expect_equal(r$source, "walkup")
expect_equal(r$path, normalizePath(both))
unlink(both, recursive = TRUE)

# --- options("pensar.vault") used as fallback, source = "option" ---
v_opt <- file.path(tempdir(), paste0("vault-opt-",
                                     format(Sys.time(), "%H%M%S")))
init_vault(v_opt, rproj = FALSE, agent_instructions = FALSE)
options(pensar.vault = v_opt)
# Start in a dir that has no vault anywhere up the tree.
isolated <- file.path(tempdir(), paste0("isolated-",
                                        format(Sys.time(), "%H%M%S")))
dir.create(isolated)
r <- resolve_vault(start = isolated)
expect_equal(r$source, "option")
expect_equal(r$path, normalizePath(v_opt))
options(pensar.vault = NULL)
unlink(v_opt, recursive = TRUE)
unlink(isolated, recursive = TRUE)

# --- No resolver hits: error with setup hint ---
empty <- file.path(tempdir(), paste0("empty-",
                                     format(Sys.time(), "%H%M%S")))
dir.create(empty)
expect_error(resolve_vault(start = empty), "No pensar vault configured")
unlink(empty, recursive = TRUE)

# --- exported default_vault() getter returns the resolved path ---
# Public getter paired with use_vault(); must be callable without ::: .
# Use PENSAR_VAULT so the result is independent of the suite's cwd
# (default_vault() takes no `start`, so it resolves from getwd()).
v_def <- file.path(tempdir(), paste0("vault-def-",
                                     format(Sys.time(), "%H%M%S")))
init_vault(v_def, rproj = FALSE, agent_instructions = FALSE)
Sys.setenv(PENSAR_VAULT = v_def)
dv <- default_vault()
expect_equal(dv, normalizePath(v_def))
expect_true(is.character(dv) && length(dv) == 1L)
Sys.unsetenv("PENSAR_VAULT")
unlink(v_def, recursive = TRUE)

# --- status() carries source label through to the object ---
v_st <- file.path(tempdir(), paste0("vault-st-",
                                    format(Sys.time(), "%H%M%S")))
init_vault(v_st, rproj = FALSE, agent_instructions = FALSE)

# Explicit vault arg -> source = "explicit"
st <- status(vault = v_st)
expect_equal(st$source, "explicit")
out <- capture.output(print(st))
expect_true(any(grepl("via explicit vault argument", out)))

# Default resolution -> source from resolver (env in this case)
Sys.setenv(PENSAR_VAULT = v_st)
st <- status()
expect_equal(st$source, "env")
out <- capture.output(print(st))
expect_true(any(grepl("via PENSAR_VAULT", out)))
Sys.unsetenv("PENSAR_VAULT")

unlink(v_st, recursive = TRUE)
