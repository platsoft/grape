I would recommend something like the [jQuery JavaScript Style Guide][0] with the following explicit alterations, handed down to me. Also write code that is [strict complaint][use_strict].

- use tabs(\t) for spacing.
- `if`, `for` and `function` starting blocks need to be on a new line. 

	if (true) 
	{
		console.log("Code should be like paragraphs, with a single paragraph containing a nice nugget unit of work");
	}

- except for in line functions.

	app.get(function(req, res, next) {
		res.json({ pojo: "POJO stands for Plain Old JavaScript Object",
			double_quotes: "Use double quotes for string types",
			separate_words_with_underscore: "I think you get what they want here"
	});

[0]: https://contribute.jquery.org/style-guide/js/
[use_strict]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions_and_function_scope/Strict_mode
