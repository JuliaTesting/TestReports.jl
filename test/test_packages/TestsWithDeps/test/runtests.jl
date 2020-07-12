using TestsWithDeps, Dictionaries, Test

@test create_hash_dict(1, 2) == Dictionary(["key1", "key2"], [1, 2])