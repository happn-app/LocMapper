#!/bin/bash

echo "DO THIS (do not forget the VERSION variable, set to a marketing version)"
echo "If need be, you can add a --revision N to create a new revision of the same version"
echo 'mkdeb build --from linux_build/products/release.tar.gz --recipe Scripts/zz_assets/mkdeb locmapper:amd64=$VERSION'
