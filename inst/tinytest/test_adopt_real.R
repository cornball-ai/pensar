# Adopt mode against real Obsidian vaults.
# Skipped on CRAN: runs only at_home() and only when the test vaults
# are present locally. Each vault is copied to tempdir, adopted, and
# unlinked; nothing in the source ~/pensar-test-vaults tree is touched.

library(pensar)

if (!at_home()) {
    exit_file("Skip on CRAN / R CMD check; runs at_home() only.")
}

vaults_dir <- Sys.getenv("PENSAR_TEST_VAULTS", "~/pensar-test-vaults")
vaults_dir <- path.expand(vaults_dir)
if (!dir.exists(vaults_dir)) {
    exit_file(sprintf("Test vaults not found at %s", vaults_dir))
}

vaults <- list.dirs(vaults_dir, recursive = FALSE)
expect_true(length(vaults) >= 1L)

for (src in vaults) {
    name <- basename(src)
    parent <- tempfile("adopt-")
    dir.create(parent)
    on.exit(unlink(parent, recursive = TRUE), add = TRUE)
    ok_copy <- suppressWarnings(file.copy(src, parent, recursive = TRUE,
                                          copy.mode = FALSE))
    if (!isTRUE(ok_copy)) {
        next
    }
    dest <- file.path(parent, name)

    pensar::init_vault(dest, adopt = TRUE, rproj = FALSE,
                       agent_instructions = FALSE)

    expect_true(pensar:::vault_is_adopted(dest),
                info = sprintf("%s: adopt flag set", name))
    expect_true(file.exists(file.path(dest, "schema.md")),
                info = sprintf("%s: schema.md written", name))
    expect_true(file.exists(file.path(dest, "log.md")),
                info = sprintf("%s: log.md written", name))

    reg <- suppressWarnings(
        pensar::vault_registry(vault = dest, cache = "none", refresh = TRUE))
    expect_true(is.data.frame(reg),
                info = sprintf("%s: vault_registry returns a data.frame", name))

    # Ingest writes are refused without force.
    err <- tryCatch(pensar::ingest("body text", source = "test://1",
                                   title = "Refused", vault = dest),
                    error = function(e) conditionMessage(e))
    expect_true(grepl("[Aa]dopt", err),
                info = sprintf("%s: ingest refuses adopted writes", name))

    # write_wiki_page refused without force; allowed with force.
    err2 <- tryCatch(pensar:::write_wiki_page(
        "Adopt-Probe",
        frontmatter = list(title = "Adopt Probe", type = "analysis",
                           source = "adopt-test"),
        body = "Probe body", vault = dest),
        error = function(e) conditionMessage(e))
    expect_true(grepl("[Aa]dopt", err2),
                info = sprintf("%s: write_wiki_page refuses adopted writes",
                               name))

    forced <- pensar:::write_wiki_page(
        "Adopt-Probe",
        frontmatter = list(title = "Adopt Probe", type = "analysis",
                           source = "adopt-test"),
        body = "Probe body", vault = dest, force = TRUE)
    expect_equal(forced$slug, "Adopt-Probe",
                 info = sprintf("%s: force = TRUE writes through", name))
    expect_true(file.exists(file.path(dest, "wiki", "Adopt-Probe.md")),
                info = sprintf("%s: forced write lands on disk", name))

    unlink(parent, recursive = TRUE)
}
