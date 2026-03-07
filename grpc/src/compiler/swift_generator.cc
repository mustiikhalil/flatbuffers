/*
 * Copyright 2020 Google Inc. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * NOTE: The following implementation is a translation for the Swift-grpc
 * generator since flatbuffers doesnt allow plugins for now. if an issue arises
 * please open an issue in the flatbuffers repository. This file should always
 * be maintained according to the Swift-grpc repository
 */
#include "src/compiler/swift_generator.h"

#include <map>
#include <sstream>

#include "flatbuffers/util.h"
#include "src/compiler/schema_interface.h"

namespace grpc_swift_generator {
namespace {

static std::string ServerResponse() {
  return "GRPCCore.ServerResponse";
}

static std::string ServerRequest() {
  return "GRPCCore.ServerRequest";
}

static std::string StreamingServerRequest() {
  return "GRPCCore.StreamingServerRequest";
}

static std::string StreamingServerResponse() {
  return "GRPCCore.StreamingServerResponse";
}

static std::string QualifiedName(const std::vector<std::string>& components,
                                   const grpc::string& name,
                                   const std::string separator = "_") {
  std::string qualified_name;
  for (auto it = components.begin(); it != components.end(); ++it)
    qualified_name += *it + separator;
  return qualified_name + name;
}

static std::string GenerateType(const std::string name,
                                const std::string wrapper) {
  return wrapper + "<GRPCMessage<" + name + ">>";
}

void EnforceOSVersion(grpc_generator::Printer* printer) {
  printer->Print("@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)\n");
}

void Method(grpc_generator::Printer* printer,
            std::map<grpc::string, grpc::string>* dictonary) {
  auto vars = *dictonary;
  printer->Print(vars, "$ACCESS$ enum $MethodName$: Sendable {\n");
  printer->Indent();
  printer->Print(vars, "$ACCESS$ typealias Input = FlatBufferBuilder\n");
  printer->Print(vars, "$ACCESS$ typealias Output = $Output$\n");
  printer->Print(vars, "$ACCESS$ static let descriptor = GRPCCore.MethodDescriptor(\n");
  printer->Indent();
  printer->Print(vars, "service: GRPCCore.ServiceDescriptor(fullyQualifiedService: \"$ServiceQualifiedName$\"),\n");
  printer->Print(vars, "method: \"$MethodName$\"\n");
  printer->Outdent();
  printer->Print(")\n");
  printer->Outdent();
  printer->Print(vars, "}\n");
}

void GenerateCoders(const grpc_generator::Service* service,
                    grpc_generator::Printer* printer,
                    std::map<grpc::string, grpc::string>* dictonary) {
  EnforceOSVersion(printer);
  printer->Print("extension FlatBuffersMessageSerializer: MessageSerializer {\n");
  printer->Indent();
  printer->Print("public func serialize<Bytes>(_ message: Message) throws -> Bytes where Bytes : GRPCCore.GRPCContiguousBytes {\n");
  printer->Indent();
  printer->Print("do {\n");
  printer->Indent();
  printer->Print("return try self.serialize(message: message) as! Bytes\n");
  printer->Outdent();
  printer->Print("} catch let error {\n");
  printer->Indent();
  printer->Print("throw RPCError(\n");
  printer->Indent();
  printer->Print("code: .invalidArgument,\n");
  printer->Print("message: \"Can't serialize message\",\n");
  printer->Print("cause: error\n");
  printer->Outdent();
  printer->Print(")\n");
  printer->Outdent();
  printer->Print("}\n");
  printer->Outdent();
  printer->Print("}\n");
  printer->Outdent();
  printer->Print("}\n\n");

  EnforceOSVersion(printer);
  printer->Print("extension FlatBuffersMessageDeserializer: MessageDeserializer {\n");
  printer->Indent();
  printer->Print("public func deserialize<Bytes>(_ serializedMessageBytes: Bytes) throws -> Message where Bytes : GRPCCore.GRPCContiguousBytes {\n");
  printer->Indent();
  printer->Print("do {\n");
  printer->Indent();
  printer->Print("return try serializedMessageBytes.withUnsafeBytes {\n");
  printer->Indent();
  printer->Print("try self.deserialize(pointer: $0)\n");
  printer->Outdent();
  printer->Print("}\n");
  printer->Outdent();
  printer->Print("} catch let error {\n");
  printer->Indent();
  printer->Print("throw RPCError(\n");
  printer->Indent();
  printer->Print("code: .invalidArgument,\n");
  printer->Print("message: \"Can't Decode message of type \\(Message.self)\",\n");
  printer->Print("cause: error\n");
  printer->Outdent();
  printer->Print(")\n");
  printer->Outdent();
  printer->Print("}\n");
  printer->Outdent();
  printer->Print("}\n");
  printer->Outdent();
  printer->Print("}\n");
}

void GenerateSharedContent(const grpc_generator::Service* service,
                            grpc_generator::Printer* printer,
                            std::map<grpc::string, grpc::string>* dictonary) {
  auto vars = *dictonary;
  EnforceOSVersion(printer);
  printer->Print(
      vars,
      "$ACCESS$ enum $SwiftServiceQualifiedName$: Sendable {\n");
  printer->Indent();
  printer->Print(vars, "$ACCESS$ static let descriptor = GRPCCore.ServiceDescriptor(fullyQualifiedService: \"$ServiceQualifiedName$\")\n");
  printer->Print(vars, "$ACCESS$ enum Method: Sendable {\n");
  printer->Indent();

  std::vector<std::string> descriptors;
  for (auto it = 0; it < service->method_count(); it++) {
    auto method = service->method(it);
    vars["Input"] = QualifiedName(method->get_input_namespace_parts(),
                                     method->get_output_type_name());
    vars["Output"] = QualifiedName(method->get_output_namespace_parts(),
                                     method->get_output_type_name());
    auto name = method->name();
    vars["MethodName"] = name;
    descriptors.push_back(name);
    Method(printer, &vars);
  }

  printer->Print(vars, "$ACCESS$ static let descriptors: [GRPCCore.MethodDescriptor] = [\n");
  printer->Indent();
  for (auto it = descriptors.begin(); it < descriptors.end(); it++) {
    vars["MethodName"] = *it;
    printer->Print(vars, "$MethodName$.descriptor,\n");
  }
  printer->Outdent();
  printer->Print("]\n");
  printer->Outdent();
  printer->Print("}\n");

  printer->Outdent();
  printer->Print("}\n\n");

  EnforceOSVersion(printer);
  printer->Print("extension GRPCCore.ServiceDescriptor {\n");
  printer->Indent();
  printer->Print(vars, "$ACCESS$ static let $SwiftServiceQualifiedName$ = GRPCCore.ServiceDescriptor(fullyQualifiedService: \"$ServiceQualifiedName$\")\n");
  printer->Outdent();
  printer->Print("}\n\n");
}

// Service Generation

void GenerateFunction(grpc_generator::Printer* printer, std::map<grpc::string, grpc::string>* dictonary) {
  auto vars = *dictonary;
  printer->Print(vars, "func $MethodName$(\n");
  printer->Indent();

  printer->Print(vars, "request: $Input$,\n");
  printer->Print("context: GRPCCore.ServerContext\n");

  printer->Outdent();
  printer->Print(vars, ") async throws -> $Output$\n\n");
}

void GenerateServiceProtocols(const grpc_generator::Service* service,
                              grpc_generator::Printer* printer,
                              std::map<grpc::string, grpc::string>* dictonary) {
  auto vars = *dictonary;
  EnforceOSVersion(printer);
  printer->Print(
                 vars,
                 "extension $SwiftServiceQualifiedName$ {\n");
  printer->Indent();
  printer->Print(vars, "$ACCESS$ protocol StreamingServiceProtocol: GRPCCore.RegistrableRPCService {\n");
  printer->Indent();

  for (auto it = 0; it < service->method_count(); it++) {
    auto method = service->method(it);
    vars["Input"] = GenerateType(QualifiedName(method->get_input_namespace_parts(), method->get_output_type_name()), StreamingServerRequest());

    vars["Output"] = GenerateType(QualifiedName(method->get_input_namespace_parts(), method->get_output_type_name()), StreamingServerResponse());
    auto name = method->name();
    vars["MethodName"] = name;
    GenerateFunction(printer, &vars);
  }
  printer->Outdent();
  printer->Print("}\n\n");

  printer->Print(vars, "$ACCESS$ protocol ServiceProtocol: $SwiftServiceQualifiedName$.StreamingServiceProtocol {\n");
  printer->Indent();

  for (auto it = 0; it < service->method_count(); it++) {
    auto method = service->method(it);

    std::string input;
    std::string output;
    if (method->BidiStreaming()) {
      input = StreamingServerRequest();
      output = StreamingServerResponse();
    } else if (method->ClientStreaming()) {
      input = StreamingServerRequest();
      output = ServerResponse();
    } else if (method->ServerStreaming()) {
      input = ServerRequest();
      output = StreamingServerResponse();
    } else {
      input = ServerRequest();
      output = ServerResponse();
    }

    vars["Input"] = GenerateType(QualifiedName(method->get_input_namespace_parts(), method->get_output_type_name()), input);

    vars["Output"] = GenerateType(QualifiedName(method->get_input_namespace_parts(), method->get_output_type_name()), output);
    auto name = method->name();
    vars["MethodName"] = name;
    GenerateFunction(printer, &vars);
  }

  printer->Outdent();
  printer->Print("}\n");

  // TODO: - Generate simple service protocol

  printer->Outdent();
  printer->Print("}\n\n");

  EnforceOSVersion(printer);
  printer->Print(vars, "extension $SwiftServiceQualifiedName$.StreamingServiceProtocol {\n");
  printer->Indent();
  printer->Print("public func registerMethods<Transport>(with router: inout GRPCCore.RPCRouter<Transport>) where Transport: GRPCCore.ServerTransport {\n");
  printer->Indent();

  for (auto it = 0; it < service->method_count(); it++) {
    auto method = service->method(it);
    vars["Input"] = GenerateType(QualifiedName(method->get_input_namespace_parts(), method->get_output_type_name()), "FlatBuffersMessageSerializer");

    vars["Output"] = GenerateType(QualifiedName(method->get_input_namespace_parts(), method->get_output_type_name()), "FlatBuffersMessageDeserializer");

    auto name = method->name();
    vars["MethodName"] = name;

    printer->Print("router.registerHandler(\n");
    printer->Indent();
    printer->Print(vars, "forMethod: $SwiftServiceQualifiedName$.Method.$MethodName$.descriptor,\n");
    printer->Print(vars, "deserializer: $Output$(),\n");
    printer->Print(vars, "serializer: $Input$(),\n");
    printer->Print("handler: { request, context in\n");
    printer->Indent();
    printer->Print(vars, "try await self.$MethodName$(\n");
    printer->Indent();
    printer->Print("request: request,\n");
    printer->Print("context: context\n");
    printer->Outdent();
    printer->Print(")\n");
    printer->Outdent();
    printer->Print("}\n");
    printer->Outdent();
    printer->Print(")\n");
  }

  printer->Outdent();
  printer->Print("}\n");
  printer->Outdent();
  printer->Print("}\n\n");
}

void GenerateService(const grpc_generator::Service* service,
                            grpc_generator::Printer* printer,
                            std::map<grpc::string, grpc::string>* dictonary) {
  GenerateServiceProtocols(service, printer, dictonary);

}

}  // namespace

grpc::string Generate(grpc_generator::File* file,
                      const grpc_generator::Service* service) {
  grpc::string output;
  std::map<grpc::string, grpc::string> vars;
  vars["PATH"] = file->package();
  if (!file->package().empty()) {
    vars["PATH"].append(".");
  }
  vars["SwiftServiceQualifiedName"] = QualifiedName(service->namespace_parts(), service->name());
  vars["ServiceQualifiedName"] = QualifiedName(service->namespace_parts(), service->name(), ".");
  vars["ServiceName"] = service->name();
  vars["ACCESS"] = service->is_internal() ? "internal" : "public";
  auto printer = file->CreatePrinter(&output);
  printer->Print(
      vars,
      "/// Usage: instantiate $ServiceQualifiedName$ServiceClient, then call "
      "methods of this protocol to make API calls.\n");
  GenerateCoders(service, &*printer, &vars);
  GenerateSharedContent(service, &*printer, &vars);
  GenerateService(service, &*printer, &vars);
//  GenerateClientClass(&*printer, &vars);
//  printer->Print("\n");
//  GenerateServerProtocol(service, &*printer, &vars);
//  printer->Print("\n");
  printer->Print("#endif\n");
  return output;
}

grpc::string GenerateHeader() {
  grpc::string code;
  code +=
      "/// The following code is generated by the Flatbuffers library which "
      "might not be in sync with grpc-swift\n";
  code +=
      "/// in case of an issue please open github issue, though it would be "
      "maintained\n";
  code += "\n";
  code += "// swiftlint:disable all\n";
  code += "// swiftformat:disable all\n";
  code += "\n";
  code += "#if !os(Windows)\n";
  code += "import FlatBuffers\n";
  code += "import Foundation\n";
  code += "import GRPCCore\n";
  code += "\n";
  return code;
}
}  // namespace grpc_swift_generator
