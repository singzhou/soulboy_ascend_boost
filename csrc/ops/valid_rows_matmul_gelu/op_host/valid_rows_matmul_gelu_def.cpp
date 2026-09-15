#include "register/op_def_registry.h"

namespace ops {
class ValidRowsMatmulGelu : public OpDef {
public:
    explicit ValidRowsMatmulGelu(const char *name) : OpDef(name)
    {
        this->Input("x").ParamType(REQUIRED).DataType({ge::DT_FLOAT16}).Format({ge::FORMAT_ND});
        this->Input("weight").ParamType(REQUIRED).DataType({ge::DT_FLOAT16}).Format({ge::FORMAT_ND});
        this->Input("bias").ParamType(REQUIRED).DataType({ge::DT_FLOAT}).Format({ge::FORMAT_ND});
        this->Input("valid_rows")
            .ParamType(REQUIRED)
            .DataType({ge::DT_INT64})
            .Format({ge::FORMAT_ND})
            .ValueDepend(OPTIONAL, DependScope::TILING);
        this->Output("y").ParamType(REQUIRED).DataType({ge::DT_FLOAT16}).Format({ge::FORMAT_ND});
        this->AICore().AddConfig("ascend910b");
    }
};

OP_ADD(ValidRowsMatmulGelu);
}  // namespace ops
