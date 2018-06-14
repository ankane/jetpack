#!/usr/bin/env sh

R --vanilla << EOF
options(repos=list(CRAN="https://cloud.r-project.org/"));
install.packages("devtools");
devtools::install_github("ankane/jetpack");
EOF

cat > /usr/local/bin/jetpack <<EOF
#!/usr/bin/env Rscript

library(jetpack)
jetpack.cli()
EOF

chmod +x /usr/local/bin/jetpack
