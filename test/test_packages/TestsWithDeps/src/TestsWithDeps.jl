module TestsWithDeps

using Dictionaries

export create_hash_dict

create_hash_dict(a, b) = Dictionary(["key1", "key2"], [a, b])

end # module
