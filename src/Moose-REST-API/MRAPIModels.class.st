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

	"Delete a model from the server"

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'models/delete/<modelID>'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #none
	schema: #object>
	MooseModel root remove: (self retrieveModel: aRequest).
	^ MROutput json value: TeaResponse ok
]

{ #category : #accessing }
MRAPIModels class >> getVerveineJPath [

	"I return the path to the executable for VerveineJ depending of the operating system"

	(FileSystem workingDirectory / 'VerveineJ' / 'VerveineJ-2.0.2')
		exists ifFalse: [ 
		'https://github.com/moosetechnology/VerveineJ/archive/refs/tags/v2.0.2.zip'
			asZnUrl saveContentsToFile:
			FileSystem workingDirectory / 'VerveineJ.zip'.
		ZipArchive new
			readFrom: FileSystem workingDirectory / 'VerveineJ.zip';
			extractAllTo: FileSystem workingDirectory / 'VerveineJ'.

		FileSystem workingDirectory / 'VerveineJ' / 'VerveineJ-2.0.2' ].
	OSPlatform current isWindows ifTrue: [ 
		^ (FileSystem workingDirectory / 'VerveineJ' / 'VerveineJ-2.0.2'
		   / 'verveinej.bat') fullName ].
	LibC runCommand: 'chmod +x '
		, (FileSystem workingDirectory / 'VerveineJ' / 'VerveineJ-2.0.2'
			 / 'verveinej.sh') fullName.
	^ (FileSystem workingDirectory / 'VerveineJ' / 'VerveineJ-2.0.2'
	   / 'verveinej.sh') fullName
]

{ #category : #api }
MRAPIModels class >> import: aRequest [

	"Create a new model in the server based on its github URL"

	<REST_API: 'POST' versions: #( 'v1' ) pattern: 'models/import'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json
	schema: #object>
	| url object verveineJPath mseName |
	object := NeoJSONObject fromString: aRequest znRequest entity string.
	url := object
		       at: #url
		       ifAbsent: [ 
		       ^ MROutput json value:
			         (TeaResponse badRequest body: aRequest) ].
	verveineJPath := self getVerveineJPath.
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

	"I return the list of model accessible with the API. For each model, I provide its id and its name."

	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json schema:
	#array>
	<REST_API: 'GET' versions: #( 'v1' ) pattern: 'models'>
	^ MROutput json value: (TeaResponse ok body:
			   (MooseModel root collectWithIndex: [ :model :idx | 
				    { 
					    ('id' -> idx).
					    ('name' -> model name) } asDictionary ]))
]
