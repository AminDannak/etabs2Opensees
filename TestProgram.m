% TestSubclass.sayHi(' Amin');
% d = TestDomain();
% d.addOneToProp(d.p2);
% disp(d.p2);
% function c = addMe(a,b)
%     switch nargin
%         case 2
%             c = a + b;
%         case 1
%             c = a + a;
%         otherwise
%             c = 0;
%     end
% end
% 
% % disp('addme(1,2)')
% disp(addme(1,2))
% disp

subObj = TestSubclass(1,2);
subObj.showLocation();