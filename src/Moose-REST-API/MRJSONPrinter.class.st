Class {
	#name : #MRJSONPrinter,
	#superclass : #FMJSONPrinter,
	#instVars : [
		'model'
	],
	#category : #'Moose-REST-API'
}

{ #category : #parsing }
MRJSONPrinter >> internalId: mooseID [
	
	stream 
		nextPutAll: '"fm.id":';
		print: mooseID;
		nextPut: $,
]
