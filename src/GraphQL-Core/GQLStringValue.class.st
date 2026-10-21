Class {
	#name : 'GQLStringValue',
	#superclass : 'GQLScalarValue',
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'printing' }
GQLStringValue >> printGraphQLOn: aStream [
	"Print as a quoted GraphQL string literal with escapes"

	| escapes |
	escapes := Dictionary new.
	escapes
		at: 34 put: '\"';
		at: 92 put: '\\';
		at: 8 put: '\b';
		at: 12 put: '\f';
		at: 10 put: '\n';
		at: 13 put: '\r';
		at: 9 put: '\t'.
	aStream nextPut: $".
	value do: [ :char |
			| code |
			code := char codePoint.
			escapes
				at: code
				ifPresent: [ :escape | aStream nextPutAll: escape ]
				ifAbsent: [
						(code < 16r20 or: [ code = 16r7F ])
							ifTrue: [
									aStream
										nextPutAll: '\u';
										nextPutAll:
											(code printStringBase: 16 length: 4 padded: true) ]
							ifFalse: [ aStream nextPut: char ] ] ].
	aStream nextPut: $"
]
