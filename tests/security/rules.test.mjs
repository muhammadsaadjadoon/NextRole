import {readFileSync} from 'node:fs';
import {test,before,after,beforeEach} from 'node:test';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,updateDoc} from 'firebase/firestore';
let env;
const profile=(role='candidate')=>({name:'Saadi',email:'saadi@example.com',role,active:true,companyApproved:role==='employer',headline:'',phone:'',location:'',bio:'',skills:'',education:'',experience:'',company:'Orbit',website:'',photo:'',saved:[]});
const job=()=>({ownerId:'employer',company:'Orbit',title:'Flutter developer',description:'Build apps',skills:'Flutter',location:'Islamabad',salary:'Not disclosed',type:'Full-time',mode:'Remote',field:'Engineering',deadline:new Date(Date.now()+86400000).toISOString(),deadlineMs:Date.now()+86400000,createdAt:new Date().toISOString(),approval:'approved',open:true});
const application=()=>({jobId:'job',ownerId:'employer',candidateId:'candidate',jobTitle:'Flutter developer',company:'Orbit',name:'Saadi',email:'saadi@example.com',headline:'',skills:'',education:'',experience:'',cover:'Hello',status:'Applied',createdAt:new Date().toISOString(),cvPath:'',cvName:''});
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-nextrole',firestore:{host:'127.0.0.1',port:8085,rules:readFileSync('../../firestore.rules','utf8')}});});
after(async()=>{await env.cleanup();});
beforeEach(async()=>{await env.clearFirestore();await env.withSecurityRulesDisabled(async(c)=>{for(const role of ['candidate','employer','admin']){await setDoc(doc(c.firestore(),'users',role),profile(role));}await setDoc(doc(c.firestore(),'jobs','job'),job());});});
const db=(id)=>env.authenticatedContext(id,{email:'saadi@example.com'}).firestore();
test('anonymous cannot read jobs',async()=>{await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'jobs','job')));});
test('candidate can read approved job',async()=>{await assertSucceeds(getDoc(doc(db('candidate'),'jobs','job')));});
test('candidate cannot self promote',async()=>{await assertFails(updateDoc(doc(db('candidate'),'users','candidate'),{role:'admin'}));});
test('employer cannot self approve company',async()=>{await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users','employer'),{companyApproved:false}));await assertFails(updateDoc(doc(db('employer'),'users','employer'),{companyApproved:true}));});
test('company identity change resets approval',async()=>{await assertFails(updateDoc(doc(db('employer'),'users','employer'),{company:'Fake'}));await assertSucceeds(updateDoc(doc(db('employer'),'users','employer'),{company:'New company',companyApproved:false}));});
test('candidate creates own application and cannot change decision',async()=>{await assertSucceeds(setDoc(doc(db('candidate'),'applications','job_candidate'),application()));await assertFails(updateDoc(doc(db('candidate'),'applications','job_candidate'),{status:'Selected'}));});
test('employer updates decision only',async()=>{await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'applications','job_candidate'),application()));await assertSucceeds(updateDoc(doc(db('employer'),'applications','job_candidate'),{status:'Shortlisted'}));await assertFails(updateDoc(doc(db('employer'),'applications','job_candidate'),{email:'fake@example.com'}));});
test('other candidate cannot read CV application',async()=>{await env.withSecurityRulesDisabled(async(c)=>{await setDoc(doc(c.firestore(),'users','other'),profile());await setDoc(doc(c.firestore(),'applications','job_candidate'),application());});await assertFails(getDoc(doc(db('other'),'applications','job_candidate')));});
test('expired job rejects application',async()=>{await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'jobs','job'),{deadlineMs:Date.now()-86400000}));await assertFails(setDoc(doc(db('candidate'),'applications','job_candidate'),application()));});
test('employer cannot publish without admin approval',async()=>{await assertFails(setDoc(doc(db('employer'),'jobs','new'),job()));await assertSucceeds(setDoc(doc(db('employer'),'jobs','new'),{...job(),approval:'pending'}));});
test('admin can approve listing',async()=>{await assertSucceeds(updateDoc(doc(db('admin'),'jobs','job'),{approval:'approved'}));});

test('candidate may withdraw own application but not alter profile snapshot',async()=>{
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'applications','job_candidate'),application()));
 await assertFails(updateDoc(doc(db('candidate'),'applications','job_candidate'),{status:'Withdrawn',name:'Changed'}));
 await assertSucceeds(updateDoc(doc(db('candidate'),'applications','job_candidate'),{status:'Withdrawn'}));
 await assertFails(updateDoc(doc(db('employer'),'applications','job_candidate'),{status:'Selected'}));
 await assertFails(updateDoc(doc(db('candidate'),'applications','job_candidate'),{status:'Applied'}));
});
test('selected applications cannot be withdrawn',async()=>{
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'applications','job_candidate'),{...application(),status:'Selected'}));
 await assertFails(updateDoc(doc(db('candidate'),'applications','job_candidate'),{status:'Withdrawn'}));
});
test('employer cannot mark application withdrawn on candidate behalf',async()=>{
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'applications','job_candidate'),application()));
 await assertFails(updateDoc(doc(db('employer'),'applications','job_candidate'),{status:'Withdrawn'}));
});
