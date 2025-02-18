
# aliases used primarily for nicer / normalized text output
`_renv_aliases` <- list(
  bioconductor = "Bioconductor",
  bitbucket    = "Bitbucket",
  cellar       = "Cellar",
  cran         = "CRAN",
  git2r        = "Git",
  github       = "GitHub",
  gitlab       = "GitLab",
  local        = "Local",
  repository   = "Repository",
  standard     = "Repository",
  url          = "URL",
  xgit         = "Git"
)

alias <- function(text) {
  `_renv_aliases`[[text]] %||% text
}
