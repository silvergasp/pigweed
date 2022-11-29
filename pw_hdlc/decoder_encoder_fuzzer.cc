// Copyright 2022 The Pigweed Authors
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

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <vector>

#include "pw_assert/check.h"
#include "pw_fuzzer/fuzzed_data_provider.h"
#include "pw_hdlc/decoder.h"
#include "pw_hdlc/encoder.h"
#include "pw_stream/memory_stream.h"
#include "pw_stream/stream.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  // The structure of this fuzzer is intended to first decode a random string of
  // bytes. If it forms a valid HDLC packet then we will re-encode and
  // assert if the buffers are different.
  constexpr int kMaxMemoryStreamSize = 1024;
  constexpr int kMaxWorkingBufferSize = 1024;
  constexpr int kMinFrameSize = 6;

  FuzzedDataProvider provider(data, size);

  std::vector<std::byte> working_buffer;
  working_buffer.resize(
      provider.ConsumeIntegralInRange(kMinFrameSize, kMaxWorkingBufferSize));
  pw::hdlc::Decoder decoder(working_buffer);

  std::vector<std::byte> hdlc_frame_data = provider.ConsumeBytes<std::byte>(
      provider.ConsumeIntegralInRange(kMinFrameSize, kMaxMemoryStreamSize));

  pw::Result<pw::hdlc::Frame> frame_result;
  size_t i = 0;
  for (i = 0; i < hdlc_frame_data.size(); i++) {
    frame_result = decoder.Process(hdlc_frame_data[i]);
    if (frame_result.ok()) {
      break;
    } else if (frame_result.status() == pw::Status::Unavailable()) {
      continue;
    } else {
      return 0;
    }
  }
  if (!frame_result.ok()) {
    return 0;
  }

  std::vector<std::byte> re_framed_data;
  re_framed_data.resize(i + 1);
  pw::stream::MemoryWriter writer(re_framed_data);

  pw::hdlc::WriteUIFrame(
      frame_result.value().address(), frame_result.value().data(), writer);

  return 0;
}