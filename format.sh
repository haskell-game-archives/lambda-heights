find src -name '*.hs' | xargs ormolu --mode inplace
find app -name '*.hs' | xargs ormolu --mode inplace
find app-win -name '*.hs' | xargs ormolu --mode inplace
