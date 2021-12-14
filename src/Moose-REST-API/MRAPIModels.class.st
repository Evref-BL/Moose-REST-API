"
I am the API to get the models
"
Class {
	#name : #MRAPIModels,
	#superclass : #MRAPI,
	#category : #'Moose-REST-API'
}

{ #category : #api }
MRAPIModels class >> delete: aRequest [

	<REST_API: 'GET' versions: #( 'v1' ) pattern: 'models/delete/<modelID>'>
	
	MooseModel root remove: (self retrieveModel: aRequest).
	^ MROutput json value: TeaResponse ok
]

{ #category : #api }
MRAPIModels class >> import: aRequest [

	<REST_API: 'POST' versions: #( 'v1' ) pattern: 'models/import'>
	| url object verveineJPath mseName |
	object := NeoJSONObject fromString: aRequest znRequest entity string.
	url := object
		       at: #url
		       ifAbsent: [ 
		       ^ MROutput json value:
			         (TeaResponse badRequest body: aRequest) ].
	verveineJPath := 'D:\Users\benoit.verhaeghe\Documents\git\moosetechnology\VerveineJ\verveinej.bat'.
	mseName := (MooseEasyUtility extractProjectNameFromGitHubURL: url)
	           , '.mse'.
	MooseEasyUtility cloneGitHubRepo: url.
	MooseEasyUtility
		createJavaMSEOn: FileSystem disk workingDirectory
		using: verveineJPath
		named: mseName.
	mseName asFileReference readStreamDo: [ :stream | 
		| model |
		model := FamixJavaModel importFromMSEStream: stream.
		model installWithCache: false ].
	^ MROutput json value: TeaResponse ok
]

{ #category : #api }
MRAPIModels class >> models: aRequest [
	<REST_API: 'GET' versions: #('v1') pattern: 'models'>
	^ MROutput json
		value: (TeaResponse ok body: (MooseModel root collectWithIndex: [ :model :idx | {('id' -> idx) . ('name' -> model name)} asDictionary ]))
]
