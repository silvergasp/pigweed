// Copyright 2021 The Pigweed Authors
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License. You may obtain a copy of
// the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations under
// the License.

#include "facade.h"

// backend.h resolves to a backend implementation at build time.
#include "backend.h"

// Ensure that a backend implementation has defined this constant as true. The
// facade.h header gives this a value of false by default.
static_assert(FACADE_BACKEND_IMPLEMENTED);
