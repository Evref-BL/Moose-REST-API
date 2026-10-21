"
Signaled by GQLLexer and GQLParser. line/column locate the error; reason is the bare message; messageText is 'Syntax Error: <reason> (line L, column C)'; #graphQLMessage answers 'Syntax Error: <reason>'.
"
Class {
	#name : 'GQLSyntaxError',
	#superclass : 'Error',
	#instVars : [
		'line',
		'column',
		'reason'
	],
	#category : 'GraphQL-Core-Lexer',
	#package : 'GraphQL-Core',
	#tag : 'Lexer'
}

{ #category : 'signalling' }
GQLSyntaxError class >> signal: aReason line: aLine column: aColumn [
	"Signal a syntax error located at aLine/aColumn (1-based).
	The messageText reads like 'Syntax Error: Unterminated string. (line 1, column 5)'"

	^ self new
		  reason: aReason;
		  line: aLine;
		  column: aColumn;
		  signal: ('Syntax Error: {1} (line {2}, column {3})' format: {
						   aReason.
						   aLine printString.
						   aColumn printString })
]

{ #category : 'accessing' }
GQLSyntaxError >> column [

	^ column
]

{ #category : 'accessing' }
GQLSyntaxError >> column: anObject [

	column := anObject
]

{ #category : 'accessing' }
GQLSyntaxError >> graphQLMessage [
	"Message in the form used by GraphQL error responses (without location suffix)"

	^ 'Syntax Error: ' , reason asString
]

{ #category : 'accessing' }
GQLSyntaxError >> line [

	^ line
]

{ #category : 'accessing' }
GQLSyntaxError >> line: anObject [

	line := anObject
]

{ #category : 'accessing' }
GQLSyntaxError >> reason [

	^ reason
]

{ #category : 'accessing' }
GQLSyntaxError >> reason: aString [

	reason := aString
]
