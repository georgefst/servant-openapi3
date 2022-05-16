-- |
-- Module:      Servant.OpenApi
-- License:     BSD3
-- Maintainer:  Nickolay Kudasov <nickolay@getshoptv.com>
-- Stability:   experimental
--
-- This module provides means to generate and manipulate
-- OpenApi specification for servant APIs.
--
-- OpenApi is a project used to describe and document RESTful APIs.
--
-- The OpenApi specification defines a set of files required to describe such an API.
-- These files can then be used by the OpenApi-UI project to display the API
-- and OpenApi-Codegen to generate clients in various languages.
-- Additional utilities can also take advantage of the resulting files, such as testing tools.
--
-- For more information see <http://swagger.io/ OpenApi documentation>.
module Servant.OpenApi (
  -- * How to use this library
  -- $howto

  -- ** Generate @'OpenApi'@
  -- $generate

  -- ** Annotate
  -- $annotate

  -- ** Test
  -- $test

  -- ** Serve
  -- $serve

  -- * @'HasOpenApi'@ class
  HasOpenApi(..),

  -- * Manipulation
  subOperations,

  -- * Testing
  validateEveryToJSON,
  validateEveryToJSONWithPatternChecker,
) where

import           Servant.OpenApi.Internal
import           Servant.OpenApi.Test
import           Servant.OpenApi.Internal.Orphans ()

-- $setup
-- >>> import Control.Applicative
-- >>> import Control.Lens
-- >>> import Data.Aeson
-- >>> import Data.OpenApi
-- >>> import Data.Typeable
-- >>> import GHC.Generics
-- >>> import Servant.API
-- >>> import Test.Hspec
-- >>> import Test.QuickCheck
-- >>> import qualified Data.ByteString.Lazy.Char8 as BSL8
-- >>> import Servant.OpenApi.Internal.Test
-- >>> :set -XDataKinds
-- >>> :set -XDeriveDataTypeable
-- >>> :set -XDeriveGeneric
-- >>> :set -XGeneralizedNewtypeDeriving
-- >>> :set -XOverloadedStrings
-- >>> :set -XTypeOperators
-- >>> data User = User { name :: String, age :: Int } deriving (Show, Generic, Typeable)
-- >>> newtype UserId = UserId Integer deriving (Show, Generic, Typeable, ToJSON)
-- >>> instance ToJSON User
-- >>> instance ToSchema User
-- >>> instance ToSchema UserId
-- >>> instance ToParamSchema UserId
-- >>> type GetUsers = Get '[JSON] [User]
-- >>> type GetUser  = Capture "user_id" UserId :> Get '[JSON] User
-- >>> type PostUser = ReqBody '[JSON] User :> Post '[JSON] UserId
-- >>> type UserAPI  = GetUsers :<|> GetUser :<|> PostUser

-- $howto
--
-- This section explains how to use this library to generate OpenApi specification,
-- modify it and run automatic tests for a servant API.
--
-- For the purposes of this section we will use this servant API:
--
-- >>> data User = User { name :: String, age :: Int } deriving (Show, Generic, Typeable)
-- >>> newtype UserId = UserId Integer deriving (Show, Generic, Typeable, ToJSON)
-- >>> instance ToJSON User
-- >>> instance ToSchema User
-- >>> instance ToSchema UserId
-- >>> instance ToParamSchema UserId
-- >>> type GetUsers = Get '[JSON] [User]
-- >>> type GetUser  = Capture "user_id" UserId :> Get '[JSON] User
-- >>> type PostUser = ReqBody '[JSON] User :> Post '[JSON] UserId
-- >>> type UserAPI  = GetUsers :<|> GetUser :<|> PostUser
--
-- Here we define a user API with three endpoints. @GetUsers@ endpoint returns a list of all users.
-- @GetUser@ returns a user given his\/her ID. @PostUser@ creates a new user and returns his\/her ID.

-- $generate
-- In order to generate @'OpenApi'@ specification for a servant API, just use @'toOpenApi'@:
--
-- >>> BSL8.putStrLn $ encodePretty $ toOpenApi (Proxy :: Proxy UserAPI)
-- {
--     "components": {
--         "schemas": {
--             "User": {
--                 "properties": {
--                     "age": {
--                         "maximum": 9223372036854775807,
--                         "minimum": -9223372036854775808,
--                         "type": "integer"
--                     },
--                     "name": {
--                         "type": "string"
--                     }
--                 },
--                 "required": [
--                     "name",
--                     "age"
--                 ],
--                 "type": "object"
--             },
--             "UserId": {
--                 "type": "integer"
--             }
--         }
--     },
--     "info": {
--         "title": "",
--         "version": ""
--     },
--     "openapi": "3.0.0",
--     "paths": {
--         "/": {
--             "get": {
--                 "responses": {
--                     "200": {
--                         "content": {
--                             "application/json;charset=utf-8": {
--                                 "schema": {
--                                     "items": {
--                                         "$ref": "#/components/schemas/User"
--                                     },
--                                     "type": "array"
--                                 }
--                             }
--                         },
--                         "description": ""
--                     }
--                 }
--             },
--             "post": {
--                 "requestBody": {
--                     "content": {
--                         "application/json;charset=utf-8": {
--                             "schema": {
--                                 "$ref": "#/components/schemas/User"
--                             }
--                         }
--                     }
--                 },
--                 "responses": {
--                     "200": {
--                         "content": {
--                             "application/json;charset=utf-8": {
--                                 "schema": {
--                                     "$ref": "#/components/schemas/UserId"
--                                 }
--                             }
--                         },
--                         "description": ""
--                     },
--                     "400": {
--                         "description": "Invalid `body`"
--                     }
--                 }
--             }
--         },
--         "/{user_id}": {
--             "get": {
--                 "parameters": [
--                     {
--                         "in": "path",
--                         "name": "user_id",
--                         "required": true,
--                         "schema": {
--                             "type": "integer"
--                         }
--                     }
--                 ],
--                 "responses": {
--                     "200": {
--                         "content": {
--                             "application/json;charset=utf-8": {
--                                 "schema": {
--                                     "$ref": "#/components/schemas/User"
--                                 }
--                             }
--                         },
--                         "description": ""
--                     },
--                     "404": {
--                         "description": "`user_id` not found"
--                     }
--                 }
--             }
--         }
--     }
-- }
--
-- By default @'toOpenApi'@ will generate specification for all API routes, parameters, headers, responses and data schemas.
--
-- For some parameters it will also add 400 and/or 404 responses with a description mentioning parameter name.
--
-- Data schemas come from @'ToParamSchema'@ and @'ToSchema'@ classes.

-- $annotate
-- While initially generated @'OpenApi'@ looks good, it lacks some information it can't get from a servant API.
--
-- We can add this information using field lenses from @"Data.OpenApi"@:
--
-- >>> :{
-- BSL8.putStrLn $ encodePretty $ toOpenApi (Proxy :: Proxy UserAPI)
--   & info.title        .~ "User API"
--   & info.version      .~ "1.0"
--   & info.description  ?~ "This is an API for the Users service"
--   & info.license      ?~ "MIT"
--   & servers           .~ ["https://example.com"]
-- :}
-- {
--     "components": {
--         "schemas": {
--             "User": {
--                 "properties": {
--                     "age": {
--                         "maximum": 9223372036854775807,
--                         "minimum": -9223372036854775808,
--                         "type": "integer"
--                     },
--                     "name": {
--                         "type": "string"
--                     }
--                 },
--                 "required": [
--                     "name",
--                     "age"
--                 ],
--                 "type": "object"
--             },
--             "UserId": {
--                 "type": "integer"
--             }
--         }
--     },
--     "info": {
--         "description": "This is an API for the Users service",
--         "license": {
--             "name": "MIT"
--         },
--         "title": "User API",
--         "version": "1.0"
--     },
--     "openapi": "3.0.0",
--     "paths": {
--         "/": {
--             "get": {
--                 "responses": {
--                     "200": {
--                         "content": {
--                             "application/json;charset=utf-8": {
--                                 "schema": {
--                                     "items": {
--                                         "$ref": "#/components/schemas/User"
--                                     },
--                                     "type": "array"
--                                 }
--                             }
--                         },
--                         "description": ""
--                     }
--                 }
--             },
--             "post": {
--                 "requestBody": {
--                     "content": {
--                         "application/json;charset=utf-8": {
--                             "schema": {
--                                 "$ref": "#/components/schemas/User"
--                             }
--                         }
--                     }
--                 },
--                 "responses": {
--                     "200": {
--                         "content": {
--                             "application/json;charset=utf-8": {
--                                 "schema": {
--                                     "$ref": "#/components/schemas/UserId"
--                                 }
--                             }
--                         },
--                         "description": ""
--                     },
--                     "400": {
--                         "description": "Invalid `body`"
--                     }
--                 }
--             }
--         },
--         "/{user_id}": {
--             "get": {
--                 "parameters": [
--                     {
--                         "in": "path",
--                         "name": "user_id",
--                         "required": true,
--                         "schema": {
--                             "type": "integer"
--                         }
--                     }
--                 ],
--                 "responses": {
--                     "200": {
--                         "content": {
--                             "application/json;charset=utf-8": {
--                                 "schema": {
--                                     "$ref": "#/components/schemas/User"
--                                 }
--                             }
--                         },
--                         "description": ""
--                     },
--                     "404": {
--                         "description": "`user_id` not found"
--                     }
--                 }
--             }
--         }
--     },
--     "servers": [
--         {
--             "url": "https://example.com"
--         }
--     ]
-- }
--
-- It is also useful to annotate or modify certain endpoints.
-- @'subOperations'@ provides a convenient way to zoom into a part of an API.
--
-- @'subOperations' sub api@ traverses all operations of the @api@ which are also present in @sub@.
-- Furthermore, @sub@ is required to be an exact sub API of @api. Otherwise it will not typecheck.
--
-- @"Data.OpenApi.Operation"@ provides some useful helpers that can be used with @'subOperations'@.
-- One example is applying tags to certain endpoints:
--
-- >>> let getOps  = subOperations (Proxy :: Proxy (GetUsers :<|> GetUser)) (Proxy :: Proxy UserAPI)
-- >>> let postOps = subOperations (Proxy :: Proxy PostUser) (Proxy :: Proxy UserAPI)
-- >>> :{
-- BSL8.putStrLn $ encodePretty $ toOpenApi (Proxy :: Proxy UserAPI)
--   & applyTagsFor getOps  ["get"  & description ?~ "GET operations"]
--   & applyTagsFor postOps ["post" & description ?~ "POST operations"]
-- :}
-- {
--     "components": {
--         "schemas": {
--             "User": {
--                 "properties": {
--                     "age": {
--                         "maximum": 9223372036854775807,
--                         "minimum": -9223372036854775808,
--                         "type": "integer"
--                     },
--                     "name": {
--                         "type": "string"
--                     }
--                 },
--                 "required": [
--                     "name",
--                     "age"
--                 ],
--                 "type": "object"
--             },
--             "UserId": {
--                 "type": "integer"
--             }
--         }
--     },
--     "info": {
--         "title": "",
--         "version": ""
--     },
--     "openapi": "3.0.0",
--     "paths": {
--         "/": {
--             "get": {
--                 "responses": {
--                     "200": {
--                         "content": {
--                             "application/json;charset=utf-8": {
--                                 "schema": {
--                                     "items": {
--                                         "$ref": "#/components/schemas/User"
--                                     },
--                                     "type": "array"
--                                 }
--                             }
--                         },
--                         "description": ""
--                     }
--                 },
--                 "tags": [
--                     "get"
--                 ]
--             },
--             "post": {
--                 "requestBody": {
--                     "content": {
--                         "application/json;charset=utf-8": {
--                             "schema": {
--                                 "$ref": "#/components/schemas/User"
--                             }
--                         }
--                     }
--                 },
--                 "responses": {
--                     "200": {
--                         "content": {
--                             "application/json;charset=utf-8": {
--                                 "schema": {
--                                     "$ref": "#/components/schemas/UserId"
--                                 }
--                             }
--                         },
--                         "description": ""
--                     },
--                     "400": {
--                         "description": "Invalid `body`"
--                     }
--                 },
--                 "tags": [
--                     "post"
--                 ]
--             }
--         },
--         "/{user_id}": {
--             "get": {
--                 "parameters": [
--                     {
--                         "in": "path",
--                         "name": "user_id",
--                         "required": true,
--                         "schema": {
--                             "type": "integer"
--                         }
--                     }
--                 ],
--                 "responses": {
--                     "200": {
--                         "content": {
--                             "application/json;charset=utf-8": {
--                                 "schema": {
--                                     "$ref": "#/components/schemas/User"
--                                 }
--                             }
--                         },
--                         "description": ""
--                     },
--                     "404": {
--                         "description": "`user_id` not found"
--                     }
--                 },
--                 "tags": [
--                     "get"
--                 ]
--             }
--         }
--     },
--     "tags": [
--         {
--             "description": "GET operations",
--             "name": "get"
--         },
--         {
--             "description": "POST operations",
--             "name": "post"
--         }
--     ]
-- }
--
-- This applies @\"get\"@ tag to the @GET@ endpoints and @\"post\"@ tag to the @POST@ endpoint of the User API.

-- $test
-- Automatic generation of data schemas uses @'ToSchema'@ instances for the types
-- used in a servant API. But to encode/decode actual data servant uses different classes.
-- For instance in @UserAPI@ @User@ is always encoded/decoded using @'ToJSON'@ and @'FromJSON'@ instances.
--
-- To be sure your Haskell server/client handles data properly you need to check
-- that @'ToJSON'@ instance always generates values that satisfy schema produced
-- by @'ToSchema'@ instance.
--
-- With @'validateEveryToJSON'@ it is possible to test all those instances automatically,
-- without having to write down every type:
--
-- >>> instance Arbitrary User where arbitrary = User <$> arbitrary <*> arbitrary
-- >>> instance Arbitrary UserId where arbitrary = UserId <$> arbitrary
-- >>> hspec $ validateEveryToJSON (Proxy :: Proxy UserAPI)
-- <BLANKLINE>
-- [User]...
-- ...
-- User...
-- ...
-- UserId...
-- ...
-- Finished in ... seconds
-- ...3 examples, 0 failures...
--
-- Although servant is great, chances are that your API clients don't use Haskell.
-- In many cases @swagger.json@ serves as a specification, not a Haskell type.
--
-- In this cases it is a good idea to store generated and annotated @'OpenApi'@ in a @swagger.json@ file
-- under a version control system (such as Git, Subversion, Mercurial, etc.).
--
-- It is also recommended to version API based on changes to the @swagger.json@ rather than changes
-- to the Haskell API.
--
-- See <example/test/TodoSpec.hs TodoSpec.hs> for an example of a complete test suite for a swagger specification.

-- $serve
-- If you're implementing a server for an API, you might also want to serve its @'OpenApi'@ specification.
--
-- See <example/src/Todo.hs Todo.hs> for an example of a server.
