#!/bin/bash
set -e

cd "$(dirname "$0")"
dot -Tpdf XcodeStringsFileParserStateGraph.dot -o XcodeStringsFileParserStateGraph.pdf
#pstopdf XcodeStringsFileParserStateGraph.ps >/dev/null
#rm XcodeStringsFileParserStateGraph.ps
