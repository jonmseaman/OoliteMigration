# Step 5: the history wraps the tokeniser in an autorelease scope (re-indenting it); step 2's VLA fix
# is re-applied to its form (the history drops the buffer itself in step 7).
RES = {"src/Core/OOStringParsing.mm": ["theirs", "theirs"]}
POST = {"src/Core/OOStringParsing.mm": [
    ("        unichar result[length];\n", "        std::vector<unichar> result(length);\n"),
    ("            token = [NSString stringWithCharacters:result length:ri];\n",
     "            token = [NSString stringWithCharacters:result.data() length:ri];\n"),
]}
