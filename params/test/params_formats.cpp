/*
 * Copyright (C) 1998-2017 ALPS Collaboration. See COPYRIGHT.TXT
 * All rights reserved. Use is subject to license terms. See LICENSE.TXT
 * For use in publications, see ACKNOWLEDGE.TXT
 */

/** @file params_formats.cpp
    
    @brief Tests various input formats for parameters
*/

#include <boost/foreach.hpp>

#include "./params_test_support.hpp"

namespace ap=alps::params_ns;
namespace de=ap::exception;
using ap::params;

namespace test_data {
    static const char inifile_content[]=
        "my_true=true\n"
        "my_false=false\n"
        "my_long=8589934593\n" // 2^33+1
        "my_float=1.25\n"
        "my_double=2.75\n"
        "my_bool_vec=true,false,true\n"
        "my_int_vec=1,2,3\n"
        "my_short_vec=10\n"
        "my_long_vec=1,2,8589934593\n"
        "my_double_vec=1.25,2.75,3.25\n"
        "my_string_vec=AAA,BBB,CC\n"
        "my_true_pair=key:true\n"
        "my_false_pair=key:false\n"
        "my_int_pair=key:10\n"
        "my_long_pair=key:8589934593\n" // 2^33+1
        "my_double_pair=key:2.75\n"
        ;
}

template <typename T, int K>
struct my_data;

#define MAKE_SOURCE2(__name__,__type__,__value__,__kind__)      \
template <>                                              \
struct my_data<__type__,__kind__> {                      \
    typedef __type__ value_type;                         \
    static __type__ get() { return __value__; }          \
    static std::string name() { return #__name__; }      \
};                                                       \
typedef my_data<__type__,__kind__> __name__;

#define MAKE_SOURCE(__name__, __type__,__value__) MAKE_SOURCE2(__name__,__type__,__value__,0)

MAKE_SOURCE2(my_true, bool,true, 1)
MAKE_SOURCE2(my_false, bool,false, 2)

MAKE_SOURCE(my_long, long, 8589934593)
MAKE_SOURCE(my_float, float, 1.25)
MAKE_SOURCE(my_double, double, 2.75)

#define MAKE_VEC3_SOURCE(__name__,__type__,__v1__,__v2__,__v3__) \
template <>                                                      \
struct my_data<std::vector<__type__>,3> {                        \
    typedef std::vector<__type__> value_type;                    \
    static std::string name() { return #__name__; }              \
    static value_type get() {                                    \
        value_type res;                                          \
        res.push_back(__v1__);                                   \
        res.push_back(__v2__);                                   \
        res.push_back(__v3__);                                   \
        return res;                                              \
    }                                                            \
};                                                               \
typedef my_data<std::vector<__type__>,3> __name__;

#define MAKE_VEC1_SOURCE(__name__,__type__,__v1__)               \
template <>                                                      \
struct my_data<std::vector<__type__>,1> {                        \
    typedef std::vector<__type__> value_type;                    \
    static std::string name() { return #__name__; }              \
    static value_type get() {                                    \
        value_type res;                                          \
        res.push_back(__v1__);                                   \
        return res;                                              \
    }                                                            \
};                                                               \
typedef my_data<std::vector<__type__>,1> __name__;

MAKE_VEC3_SOURCE(my_bool_vec, bool, true,false,true)
MAKE_VEC3_SOURCE(my_int_vec, int, 1,2,3)
MAKE_VEC3_SOURCE(my_long_vec, long, 1,2,8589934593)
MAKE_VEC3_SOURCE(my_double_vec, double, 1.25,2.75,3.25)
MAKE_VEC3_SOURCE(my_string_vec, std::string, "AAA","BBB","CC")

MAKE_VEC1_SOURCE(my_short_vec, int, 10)

template <typename T>
class ParamsTest1 : public testing::Test {
  protected:
    ParamsAndFile params_and_file_;
    params& par_;
    const params& cpar_;

    typedef T generator_type;
    typedef typename generator_type::value_type value_type;
  public:
    ParamsTest1() : params_and_file_(::test_data::inifile_content),
                    par_(*params_and_file_.get_params_ptr()),
                    cpar_(par_)
    {    }

    void read() {
        std::string name=generator_type::name();
        value_type expected=generator_type::get();
        EXPECT_TRUE(par_.define<value_type>(name, "parameter").ok());
        value_type actual=cpar_[name];
        EXPECT_EQ(expected,actual);
    }
};

typedef ::testing::Types<
    my_true
    ,
    my_false
    ,
    my_long
    ,
    my_float
    ,
    my_double
    ,
    my_bool_vec
    ,
    my_int_vec
    ,
    my_short_vec
    ,
    my_long_vec
    ,
    my_double_vec
    > MyTypes;

TYPED_TEST_CASE(ParamsTest1, MyTypes);

TYPED_TEST(ParamsTest1, read) { this->read(); }
